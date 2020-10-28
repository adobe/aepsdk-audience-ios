/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPCore
import AEPServices
import Foundation

/// Audience extension for the Adobe Experience Platform SDK
@objc(AEPMobileAudience)
public class Audience: NSObject, Extension {
    public let runtime: ExtensionRuntime
    public let name = AudienceConstants.EXTENSION_NAME
    public let friendlyName = AudienceConstants.FRIENDLY_NAME
    public static let extensionVersion = AudienceConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    private(set) var state: AudienceState?

    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()

        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            Log.error(label: getLogTagWith(functionName: #function), "Failed to create Data Queue, Audience could not be initialized")
            return
        }

        let hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: AudienceHitProcessor(responseHandler: handleNetworkResponse(entity:responseData:)))

        state = AudienceState(hitQueue: hitQueue)
    }

    // internal init added for tests
    #if DEBUG
        internal init(runtime: ExtensionRuntime, state: AudienceState) {
            self.runtime = runtime
            super.init()
            self.state = state
        }
    #endif

    /// Invoked when the `EventHub` has successfully registered the Audience extension.
    public func onRegistered() {
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleResponse(event:))
        registerListener(type: EventType.analytics, source: EventSource.responseContent, listener: handleAnalyticsResponse(event:))

        registerListener(type: EventType.audienceManager, source: EventSource.requestContent, listener: handleAudienceContentRequest(event:))
        registerListener(type: EventType.audienceManager, source: EventSource.requestIdentity, listener: handleAudienceIdentityRequest(event:))
        registerListener(type: EventType.audienceManager, source: EventSource.requestReset, listener: handleAudienceResetRequest(event:))
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponse(event:))
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        let configurationStatus = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.status ?? .none

        let identityStatus = getSharedState(extensionName: AudienceConstants.SharedStateKeys.IDENTITY, event: event)?.status ?? .none

        if event.type == EventType.audienceManager, event.source == EventSource.requestContent {
            return configurationStatus != .pending && identityStatus != .pending
        }

        return configurationStatus == .set
    }

    // MARK: Event Listeners

    /// Processes Configuration Response content events to retrieve the configuration data and privacy status settings.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleConfigurationResponse(event: Event) {
        // bail if the config data is not valid
        guard let configSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value else {
            return
        }
        state?.updateLastValidConfigSharedState(newConfigSharedState: configSharedState)
        // get the privacy status
        guard let privacyStatusStr = configSharedState[AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String else { return }
        let privacyStatus = PrivacyStatus(rawValue: privacyStatusStr) ?? PrivacyStatus.unknown
        if privacyStatus == .optedOut {
            // send opt-out hit
            state?.handleOptOut(event: event)
            createSharedState(data: state?.getStateData() ?? [:], event: event)
        }

        // if privacy status is opted out, audience manager data in the AudienceState will be cleared.
        state?.setMobilePrivacy(status: privacyStatus)
    }

    // Handles the signalWithData API by sending the AAM hit with passed event data then dispatching a response event with the visitorProfile
    /// - Parameter event: The event coming from the signalWithData API
    private func handleAudienceContentRequest(event: Event) {
        if state?.getPrivacyStatus() == PrivacyStatus.optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process AAM event as privacy status is OPT_OUT:  \(event.description)")
            // dispatch with an empty visitor profile in response if privacy is opt-out.
            dispatchResponse(visitorProfile: ["": ""], event: event)
            return
        }

        if state?.getPrivacyStatus() == PrivacyStatus.unknown {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process AAM event as privacy status is Unknown:  \(event.description)")
            // dispatch with an empty visitor profile in response if privacy is unknown.
            dispatchResponse(visitorProfile: ["": ""], event: event)
        }

        state?.updateLastValidIdentitySharedState(newIdentitySharedState: getSharedState(extensionName: AudienceConstants.SharedStateKeys.IDENTITY, event: event)?.value ?? ["": ""])

        state?.queueHit(event: event)
    }

    // Handles the getVisitorProfile API by getting the current visitorProfile then dispatching a response event with the visitorProfile
    /// - Parameter event: The event coming from the getVisitorProfile API
    private func handleAudienceIdentityRequest(event: Event) {
        // Dispatch with dpid, dpuuid and visitorProfile
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_PROFILE] = state?.getVisitorProfile()
        let responseEvent = event.createResponseEvent(name: "Audience Response Identity", type: EventType.audienceManager, source: EventSource.responseIdentity, data: eventData)

        // dispatch identity response event with shared state data
        dispatch(event: responseEvent)
    }

    // Handles the reset API which clears all the identifiers and visitorProfile then dispatches a sharedStateUpdate
    /// - Parameter event: The event coming from the reset API
    private func handleAudienceResetRequest(event: Event) {
        state?.clearIdentifiers()
        createSharedState(data: state?.getStateData() ?? [:], event: event)
    }

    /// Processes Lifecycle Response content and sends a signal to Audience Manager if aam forwarding is disabled.
    /// - Parameter:
    ///   - event: The lifecycle response event
    private func handleLifecycleResponse(event: Event) {
        guard let response = event.data else { return }
        if !response.isEmpty {
            guard let lastValidConfiguration = state?.getLastValidConfigSharedState() else {
                return
            }
            guard let aamForwardingStatus = lastValidConfiguration[AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING] as? Bool else { return }
            if state?.getPrivacyStatus() == PrivacyStatus.optedOut {
                Log.debug(label: getLogTagWith(functionName: #function), "Unable to process lifecycle response as privacy status is OPT_OUT:  \(event.description)")
                // dispatch with an empty visitor profile in response if privacy is opt-out.
                return
            }

            // a signal with data request will be made if aam forwarding is false
            if !aamForwardingStatus {
                state?.queueHit(event: event)
            }
        }
    }

    /// Processes Analytics Response content events to forward any necessary requests and to create a dictionary out of the contents of the "stuff" array.
    /// - Parameter:
    ///   - event: The analytics response event
    private func handleAnalyticsResponse(event: Event) {
        guard let response = event.data?[AudienceConstants.Analytics.SERVER_RESPONSE] as? String else { return }
        if !response.isEmpty {
            guard let responseAsData: Data = response.data(using: .utf8) else {
                return
            }
            // process the network response and create a new shared state for the audience extension
            let audienceSharedState = state?.processNetworkResponse(event: event, response: responseAsData)

            createSharedState(data: audienceSharedState ?? [:], event: event)
        }
    }

    /// Updates the Audience shared state versioned at `event` with `data`
    /// - Parameters:
    ///   - event: the event to version the shared state at
    ///   - data: data for the shared state
    private func updateSharedState(event: Event, data: [String: Any]) {
        let sharedStateData = data
        Log.trace(label: getLogTagWith(functionName: #function), "Updating Audience shared state")
        createSharedState(data: sharedStateData as [String: Any], event: event)
    }

    // MARK: Network Response Handler

    /// Invoked by the `AudienceHitProcessor` each time we receive a network response
    /// - Parameters:
    ///   - entity: The `DataEntity` that was processed by the hit processor
    ///   - responseData: the network response data if any
    private func handleNetworkResponse(entity: DataEntity, responseData: Data?) {
        var visitorProfile: [String:String] = [:]
        if state?.getPrivacyStatus() == .optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process network response as privacy status is OPT_OUT.")
            return
        }

        guard let data = entity.data as Data?, let hit = try? JSONDecoder().decode(AudienceHit.self, from: data) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Failed to decode the Audience Hit, aborting network response processing.")
            return
        }

        // if we have no response from the audience server log it and bail early
        if responseData == nil {
            Log.debug(label: getLogTagWith(functionName: #function), "No response from the server.")
            createSharedState(data: state?.getStateData() ?? [:], event: hit.event)
            dispatchResponse(visitorProfile: visitorProfile, event: hit.event)
            return
        }

        // process the network response and create a new shared state for the audience extension
        let audienceSharedState = state?.processNetworkResponse(event: hit.event, response: responseData ?? Data())

        // update audience manager shared state
        createSharedState(data: audienceSharedState ?? [:], event: hit.event)

        // retrieve the visitor profile
        visitorProfile = state?.getVisitorProfile() ?? [:]

        // dispatch the updated visitor profile in response.
        dispatchResponse(visitorProfile: visitorProfile, event: hit.event)
    }

    // MARK: Helpers

    /// Dispatches a visitor profile dictionary from a processed audience hit response.
    /// - Parameters:
    ///   - visitorProfile: The visitor profile returned in an audience hit response if any
    ///   - event: the event which triggered the audience hit
    private func dispatchResponse(visitorProfile: [String: String], event: Event) {
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_PROFILE] = visitorProfile
        let responseEvent = event.createResponseEvent(name: "Audience Manager Profile", type: EventType.audienceManager, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseEvent)
    }

    /// Helper to return a log tag
    /// - Parameters:
    ///   - functionName: the function name to be used in generating a log tag
    func getLogTagWith(functionName: String) -> String {
        return "\(name):\(functionName)"
    }
}

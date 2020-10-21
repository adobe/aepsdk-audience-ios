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
    private(set) var hitQueue: HitQueuing?

    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()

        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            Log.error(label: getLogTagWith(functionName: #function), "Failed to create Data Queue, Audience could not be initialized")
            return
        }

        hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: AudienceHitProcessor(responseHandler: handleNetworkResponse(entity:responseData:)))

        state = AudienceState()
    }

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
        guard let privacyStatusStr = event.data?[AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String else { return }
        let privacyStatus = PrivacyStatus(rawValue: privacyStatusStr) ?? PrivacyStatus.unknown
        if privacyStatus == .optedOut {
            // send opt-out hit
            handleOptOut(event: event)
            createSharedState(data: state?.getStateData() ?? [:], event: event)
        }
        // if privacy status is opted out, audience manager data in the AudienceState will be cleared.
        state?.setMobilePrivacy(status: privacyStatus)

        // update hit queue with privacy status
        hitQueue?.handlePrivacyChange(status: privacyStatus)
    }

    // Handles the signalWithData API by sending the AAM hit with passed event data then dispatching a response event with the visitorProfile
    /// - Parameter event: The event coming from the signalWithData API
    private func handleAudienceContentRequest(event: Event) {
        queueHit(event: event)
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

    private func handleLifecycleResponse(event: Event) {

    }

    private func handleAnalyticsResponse(event: Event) {

    }

    func queueHit(event: Event) {
        if state?.getPrivacyStatus() == PrivacyStatus.optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process AAM event as privacy status is OPT_OUT:  \(event.description)")
            // dispatch with an empty visitior profile in response if privacy is opt-out.
            dispatchResponse(visitorProfle: ["": ""], event: event)
            return
        }

        if state?.getPrivacyStatus() == PrivacyStatus.unknown {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process AAM event as privacy status is Unknown:  \(event.description)")
            // dispatch with an empty visitior profile in response if privacy is unknown.
            dispatchResponse(visitorProfle: ["": ""], event: event)
            return
        }

        let configurationSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value ?? ["": ""]
        let identitySharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.IDENTITY, event: event)?.value ?? ["": ""]

        let eventData = event.data as? [String: String] ?? ["": ""]

        guard let url = URL.buildAudienceHitURL(audienceState: state, configurationSharedState: configurationSharedState, identitySharedState: identitySharedState, customerEventData: eventData) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Dropping Audience hit, failed to create hit URL")
            return
        }

        let aamTimeout: TimeInterval = configurationSharedState[AudienceConstants.Configuration.AAM_TIMEOUT] as? TimeInterval ?? AudienceConstants.Default.TIMEOUT
        guard let hitData = try? JSONEncoder().encode(AudienceHit(url: url, timeout: aamTimeout, event: event)) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Dropping Audience hit, failed to encode AudienceHit")
            return
        }

        hitQueue?.queue(entity: DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: hitData))
    }

    func dispatchResponse(visitorProfle: [String: String], event: Event) {
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_PROFILE] = visitorProfle
        let responseEvent = event.createResponseEvent(name: "Audience Manager Profile", type: EventType.audienceManager, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseEvent)
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

    /// Sends an opt-out hit if the current privacy status is opted-out
    /// - Parameter event: the event responsible for sending this opt-out hit
    private func handleOptOut(event: Event) {
        guard let configSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value else { return }
        guard let aamServer = configSharedState[AudienceConstants.Configuration.AAM_SERVER] as? String else { return }
        let uuid = state?.getUuid() ?? ""

        // only send the opt-out hit if the audience manager server and uuid are not empty
        if !uuid.isEmpty && !aamServer.isEmpty {
            ServiceProvider.shared.networkService.sendOptOutRequest(aamServer: aamServer, uuid: uuid)
        }
    }

    // MARK: Network Response Handler

    /// Invoked by the `IdentityHitProcessor` each time we receive a network response
    /// - Parameters:
    ///   - entity: The `DataEntity` that was processed by the hit processor
    ///   - responseData: the network response data if any
    private func handleNetworkResponse(entity: DataEntity, responseData: Data?) {
        //state?.handleHitResponse(hit: entity, response: responseData, eventDispatcher: dispatch(event:), createSharedState: createSharedState(data:event:))

        //TODO dispatchResponse()
    }

    // MARK: Helper

    func getLogTagWith(functionName: String) -> String {
        return "\(name):\(functionName)"
    }
}

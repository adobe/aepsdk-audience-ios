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
    private static let LOG_TAG = "Audience"
    public let runtime: ExtensionRuntime
    public let name = AudienceConstants.EXTENSION_NAME
    public let friendlyName = AudienceConstants.FRIENDLY_NAME
    public static let extensionVersion = AudienceConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil

    private(set) var state: AudienceState?
    private let dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)

    // Maintains the boot up state of sdk.
    private var sdkBootUpCompleted = false

    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()

        AudienceMigrator.migrateLocalStorage(dataStore: dataStore)

        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            Log.error(label: getLogTagWith(functionName: #function), "Failed to create Data Queue, Audience could not be initialized")
            return
        }

        let hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: AudienceHitProcessor(responseHandler: handleNetworkResponse(entity:responseData:)))

        state = AudienceState(hitQueue: hitQueue, dataStore: dataStore)
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
        registerListener(type: EventType.genericIdentity, source: EventSource.requestReset, listener: handleResetIdentitiesEvent)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        let configurationStatus = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.status ?? .none

        let identityStatus = getSharedState(extensionName: AudienceConstants.SharedStateKeys.IDENTITY, event: event)?.status ?? .none

        // for signal events require both config and identity shared states
        if (event.type == EventType.audienceManager && event.source == EventSource.requestContent) ||
            (event.type == EventType.lifecycle && event.source == EventSource.responseContent) {
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
        guard let configSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value else { return }
        Log.debug(label: getLogTagWith(functionName: #function), "Received Configuration Response event, attempting to retrieve configuration settings.")
        state?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: createSharedState(data:event:), dispatchOptOutResult: dispatchOptOutResult(optedOut:event:))
        // create audience shared state on boot / valid audience configuration
        if !sdkBootUpCompleted {
            if let status = state?.isAudienceConfigured(), status == true {
                sdkBootUpCompleted.toggle()
                Log.trace(label: getLogTagWith(functionName: #function), "Creating shared state on boot event.")
                createSharedState(data: state?.getStateData() ?? [:], event: event)
            }
        }
    }

    /// Handles the signalWithData API by attempting to send the Audience Manager hit containing the passed-in event data. If a response is received for the processed `AudienceHit`, a response content event with visitor profile data is dispatched.
    /// - Parameter event: The event coming from the signalWithData API invocation
    private func handleAudienceContentRequest(event: Event) {
        Log.debug(label: getLogTagWith(functionName: #function), "Received an Audience Manager signalWithData event, attempting to queue the signalWithData hit.")
        // store the identity variables in the AudienceState
        let identitySharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.IDENTITY, event: event)?.value ?? ["": ""]
        state?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)

        // queue the signalWithData hit
        state?.queueHit(event: event, dispatchResponse: dispatchResponse(visitorProfile:event:))
    }

    /// Handles the getVisitorProfile API by dispatching a response content event containing the visitor profile stored in the `AudienceState`.
    /// - Parameter event: The event coming from the getVisitorProfile API invocation
    private func handleAudienceIdentityRequest(event: Event) {
        Log.debug(label: getLogTagWith(functionName: #function), "Received an Audience Manager getVisitorProfile event, retrieving the stored visitor profile.")
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_PROFILE] = state?.getVisitorProfile()
        let responseEvent = event.createResponseEvent(name: "Audience Manager Identities", type: EventType.audienceManager, source: EventSource.responseIdentity, data: eventData)

        // dispatch identity response event with shared state data
        dispatch(event: responseEvent)
    }

    /// Handles the reset API by clearing all the identifiers and visitorProfile in the `AudienceState`.
    /// - Parameter event: The event coming from the reset API invocation
    private func handleAudienceResetRequest(event: Event) {
        Log.debug(label: getLogTagWith(functionName: #function), "Received an Audience Manager reset event, clearing all stored Audience Manager identities and visitor profile.")
        state?.handleResetEvent(event: event)
        createSharedState(data: state?.getStateData() ?? [:], event: event)
    }

    /// Processes Lifecycle Response content and sends a signal to Audience Manager if aam forwarding is disabled.
    /// The Audience Manager shared state will be updated on Lifecycle Start events.
    /// - Parameter:
    ///   - event: The lifecycle response event
    private func handleLifecycleResponse(event: Event) {
        Log.debug(label: getLogTagWith(functionName: #function), "Received a Lifecycle Response event.")
        guard let response = event.data else {
            Log.debug(label: getLogTagWith(functionName: #function), "The Lifecycle Response event data was not present, ignoring the event.")
            return
        }
        if !response.isEmpty {
            // a signal with data request will be made if aam forwarding is false
            if !(state?.getAamForwardingStatus() ?? false) {
                Log.debug(label: getLogTagWith(functionName: #function), "The Lifecycle Response event data was valid and aam forwarding status is false, attempting to queue an Audience Hit.")
                state?.queueHit(event: event, dispatchResponse: dispatchResponse(visitorProfile:event:))
            }
        }
    }

    /// Processes Analytics Response content events to forward any necessary requests and to create a dictionary out of the contents of the "stuff" array.
    /// - Parameter:
    ///   - event: The analytics response event
    private func handleAnalyticsResponse(event: Event) {
        // quick out if aam forwarding status is false
        if let aamForwardingStatus = state?.getAamForwardingStatus(), aamForwardingStatus == false {
            Log.trace(label: getLogTagWith(functionName: #function), "Not Processing Analytics Response event as AAMForwarding is disabled.")
            return
        }
        guard let response = event.data?[AudienceConstants.Analytics.SERVER_RESPONSE] as? String else { return }
        if !response.isEmpty {
            guard let responseAsData: Data = response.data(using: .utf8) else {
                return
            }
            Log.trace(label: getLogTagWith(functionName: #function), "The Analytics response was valid, processing the response.")
            // process the analytics network response
            state?.processResponseData(event: event, response: responseAsData)

            // create a new shared state for the audience extension
            createSharedState(data: state?.getStateData() ?? [:], event: event)
        }
    }

    // MARK: Network Response Handler

    /// Invoked by the `AudienceHitProcessor` each time we receive a network response
    /// - Parameters:
    ///   - entity: The data entity responsible for the hit
    ///   - responseData: the network response data if any
    private func handleNetworkResponse(entity: DataEntity, responseData: Data?) {
        guard let data = entity.data as Data?, let hit = try? JSONDecoder().decode(AudienceHit.self, from: data) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Failed to decode the Audience Hit, aborting network response processing.")
            return
        }
        Log.debug(label: getLogTagWith(functionName: #function), "Received a network response from the Audience Manager server, attempting to process the response.")
        state?.handleHitResponse(hit: hit, responseData: responseData, dispatchResponse: dispatchResponse(visitorProfile:event:), createSharedState: createSharedState(data:event:))
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

    /// Dispatches a boolean depending on if optOut Hit  was sent successfully
    /// - Parameters:
    ///   - optedOut: the flag which is set to true if optOut Hit  was sent successfully
    ///   - event: the event which triggered the audience hit
    private func dispatchOptOutResult(optedOut: Bool, event: Event) {
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.OPTED_OUT_HIT_SENT] = optedOut
        let responseEvent = event.createResponseEvent(name: "Audience Manager Opt Out Event", type: EventType.audienceManager, source: EventSource.responseContent, data: eventData)
        dispatch(event: responseEvent)
    }

    /// Processes Reset identities event
    /// - Parameter:
    ///   - event: The Reset identities event
    private func handleResetIdentitiesEvent(_ event: Event) {
        Log.debug(label: Self.LOG_TAG, "\(#function) - Resetting all Identifiers")

        state?.handleResetEvent(event: event)
        createSharedState(data: state?.getStateData() ?? [:], event: event)
    }

    /// Helper to return a log tag
    /// - Parameters:
    ///   - functionName: the function name to be used in generating a log tag
    func getLogTagWith(functionName: String) -> String {
        return "\(name):\(functionName)"
    }
}

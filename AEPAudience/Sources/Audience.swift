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
    private(set) var state: AudienceState
    private(set) var lastValidConfig: [String:Any] = [:]

    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        state = AudienceState()
        super.init()

//        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
//            Log.error(label: getLogTagWith(functionName: #function), "Failed to create Data Queue, Audience could not be initialized")
//            return
//        }
    }

    /// Invoked when the `EventHub` has successfully registered the Audience extension.
    public func onRegistered() {
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleResponse(event:))
        registerListener(type: EventType.analytics, source: EventSource.responseContent, listener: handleAnalyticsResponse(event:))

        registerListener(type: EventType.audienceManager, source: EventSource.requestContent, listener: handleAudienceRequest(event:))
        registerListener(type: EventType.audienceManager, source: EventSource.requestIdentity, listener: handleAudienceIdentityRequest(event:))
        registerListener(type: EventType.audienceManager, source: EventSource.requestReset, listener: handleAudienceResetRequest(event:))
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponse(event:))
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.status == .set
    }

    // MARK: Event Listeners

    private func handleSharedStateUpdate(event: Event) {

    }

    /// Processes Lifecycle Response content and sends a signal to Audience Manager if aam forwarding is disabled.
    /// - Parameter:
    ///   - event: The lifecycle response event
    private func handleLifecycleResponse(event: Event) {
        guard let response = event.data else { return }
        if !response.isEmpty {
            // bail if we don't have configuration yet
            guard let configSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value else { return }
            let aamForwardingStatus = getAnalyticsAAMForwardingStatus(configurationSharedState: configSharedState)
            // a signal with data request will be made if aam forwarding is false and if audience manager configuration is ready
            if !aamForwardingStatus && readyForSignalWithData(configurationSharedState: configSharedState) {
                let eventData: [String:String] = convertLifecycleKeys(event: event)
                let signalWithDataEvent = Event(name: "Signal Event", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
                signalWithData(event: signalWithDataEvent)
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
            processNetworkResponse(event: event, response: responseAsData)
        }
    }

    private func handleAudienceRequest(event: Event) {

    }

    /// Processes Configuration Response content events to retrieve the configuration data and privacy status settings.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleConfigurationResponse(event: Event) {
        guard let privacyStatusStr = event.data?[AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String else { return }
        let privacyStatus = PrivacyStatus(rawValue: privacyStatusStr) ?? PrivacyStatus.unknown
        if privacyStatus == .optedOut {
            // send opt-out hit
            handleOptOut(event: event)
            createSharedState(data: state.getStateData(), event: event)
        }
        // if privacy status is opted out, audience manager data in the AudienceState will be cleared.
        state.setMobilePrivacyStatus(privacyStatus: privacyStatus)
    }

    private func handleAudienceIdentityRequest(event: Event) {

    }

    private func handleAudienceResetRequest(event: Event) {

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

    func getLogTagWith(functionName: String) -> String {
        return "\(name):\(functionName)"
    }

    /// Sends an opt-out hit if the current privacy status is opted-out
    /// - Parameter event: the event responsible for sending this opt-out hit
    private func handleOptOut(event: Event) {
        guard let configSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value else { return }
        guard let aamServer = configSharedState[AudienceConstants.Configuration.AAM_SERVER] as? String else { return }
        let uuid = state.getUuid()

        // only send the opt-out hit if the audience manager server and uuid are not empty
        if !uuid.isEmpty && !aamServer.isEmpty {
            ServiceProvider.shared.networkService.sendOptOutRequest(aamServer: aamServer, uuid: uuid)
        }
    }

    /// Processes a response from the Audience Manager server or Analytics extension. This function attempts to forward any necessary requests found in the AAM "dests" array, and to create a dictionary out of the contents of the "stuff" array.
    /// - Parameters:
    ///   - event: the response event to be processed
    ///   - response: the JSON response received
    private func processNetworkResponse(event: Event, response: Data) -> [String:String] {
        // bail if we don't have configuration yet
        guard let configSharedState = getSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event)?.value else { return [String:String]() }
        let timeout = getAudienceManagerTimeout(configurationSharedState: configSharedState)
        // if we have an error decoding the response, log it and bail early
        guard let audienceResponse = try? JSONDecoder().decode(AudienceHitResponse.self, from: response) else {
            Log.debug(label: "\(name):\(#function)", "Failed to decode Audience Manager response.")
            return [String:String]()
        }

        // process dests array
        processDestsArray(response: audienceResponse, timeout: timeout)

        // save uuid for use with subsequent calls
        let uuid = audienceResponse.uuid ?? ""
        state.setUuid(uuid: uuid)

        // process stuff array
        let processedStuff = processStuffArray(stuff: audienceResponse.stuff ?? [AudienceStuffObject]())

        if processedStuff.isEmpty {
            Log.trace(label: "\(name):\(#function)", "Response received: \(processedStuff).")
        } else {
            Log.trace(label: "\(name):\(#function)", "Response was empty.")
        }

        // save profile in defaults
        state.setVisitorProfile(visitorProfile: processedStuff)

        // update audience manager shared state
        createSharedState(data: state.getStateData(), event: event)

        return processedStuff
    }

    /// Reads the Audience Manager timeout from the configuration shared state. If not found, returns the default Audience Manager timeout of 2 seconds.
    /// - Parameter configurationSharedState: the data associated with the configuration shared state
    private func getAudienceManagerTimeout(configurationSharedState: [String: Any]?) -> TimeInterval {
        guard let timeout = configurationSharedState?[AudienceConstants.Configuration.AAM_TIMEOUT] as? Int else {
            return TimeInterval(AudienceConstants.Default.TIMEOUT)
        }

        return TimeInterval(timeout)
    }

    /// Reads the Analytics AAM forwarding status from the configuration shared state.
    /// - Parameter configurationSharedState: the data associated with the configuration shared state
    private func getAnalyticsAAMForwardingStatus(configurationSharedState: [String: Any]?) -> Bool {
        guard let status = configurationSharedState?[AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING] as? Bool else {
            return false
        }

        return status
    }

    /// Parses the "dests" array present in the Audience Manager response and forwards data to the url's found.
    /// - Parameters:
    ///   - response: the `AudienceHitResponse` if any
    ///   - timeout: the Audience Manager network request timeout
    private func processDestsArray(response: AudienceHitResponse, timeout: TimeInterval) {
        // check "dests" for urls to forward
        let destinations = (response.dests ?? [String]()) as [String]
        if !destinations.isEmpty {
            for dest in destinations {
                if !dest.isEmpty {
                    guard let url = URL(string: dest) else {
                        Log.error(label: "\(name):\(#function)", "Building destination URL failed, skipping forwarding for: \(dest).")
                        continue
                    }
                    Log.debug(label: "\(name):\(#function)", "Forwarding to url: \(dest).")
                    let networkRequest = NetworkRequest(url: url, httpMethod: .get, connectPayload: "", httpHeaders: [String: String](), connectTimeout: timeout, readTimeout: timeout)
                    ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest, completionHandler: nil) // fire and forget
                }
            }
        } else {
            Log.debug(label: "\(name):\(#function)", "No destinations found in response.")
        }
    }

    /// Parses the "stuff" array and returns a dictionary containing the segments for the user.
    /// - Parameters:
    ///   - stuff: the stuff dictionary contained in the `AudienceHitResponse`
    private func processStuffArray(stuff: [AudienceStuffObject]) -> [String: String] {
        var segments = [String: String]()
        if !stuff.isEmpty {
            for stuffObject in stuff {
                guard let key = stuffObject.cookieKey else {
                    Log.debug(label: "\(name):\(#function)", "Error processing stuff object with cookie name \(String(describing: stuffObject.cookieKey)).")
                    continue
                }
                guard let value = stuffObject.cookieValue else {
                    Log.debug(label: "\(name):\(#function)", "Error processing stuff object with cookie value \(String(describing: stuffObject.cookieValue)).")
                    continue
                }
                segments[key] = value
            }
        } else {
            Log.debug(label: "\(name):\(#function)", "No `stuff` array found in response.")
        }

        return segments
    }

    /// Converts Lifecycle event data to Audience Manager context data
    /// - Parameters:
    ///   - event: the `Lifecycle` response content event
    private func convertLifecycleKeys(event: Event) -> [String: String] {
        var convertedKeys = [String: String]()
        guard let lifecycleEventData:[String: String] = event.data?[AudienceConstants.Lifecycle.LIFECYCLE_CONTEXT_DATA] as? [String:String] else {
            return [String:String]()
        }

        if !lifecycleEventData.isEmpty {
            for keyValuePair in AudienceConstants.MapToContextDataKeys {
                guard let value = lifecycleEventData[keyValuePair.key] else {
                    Log.debug(label: "\(name):\(#function)", "\(keyValuePair.key) not found in lifecycle context data.")
                    continue
                }
                convertedKeys[keyValuePair.value] = value
            }
        } else {
            Log.debug(label: "\(name):\(#function)", "No data found in the lifecycle response event.")
        }

        return convertedKeys
    }

    /// Determines if we have audience manager configuration to process a signal with data request.
    /// - Parameters:
    ///   - configurationSharedState: config shared state corresponding to the event to be processed
    func readyForSignalWithData(configurationSharedState: [String: Any]) -> Bool {
        // audience server is a requirement.
        // use what's in current config shared state. if that's missing, check latest config.
        if let audienceServer = configurationSharedState[AudienceConstants.Configuration.AAM_SERVER] as? String, !audienceServer.isEmpty {
            lastValidConfig = configurationSharedState
        } else if lastValidConfig.isEmpty {
            // can't process this event, wait for a valid config and retry later
            return false
        }
        return true
    }

    /// Queues a signal with data hit.
    /// Assumes a valid config is in `lastValidConfig` from calling `readyForSignalWithData`
    /// - Parameters:
    ///   - event: event corresponding to signalWithData.
    private func signalWithData(event: Event) {
        // sanity check, config should never be empty
        if lastValidConfig.isEmpty {
            Log.debug(label: "\(name):\(#function)", "Ignoring signal with data request as last valid config is empty")
            return
        }

        // Early exit if privacy is opt-out
        if state.getPrivacyStatus() == .optedOut {
            Log.debug(label: "\(name):\(#function)", "Ignoring signal with data request as privacy is opted-out")
            return
        }

        // todo: queue the signal with data hit

        // update audience manager shared state
        createSharedState(data: state.getStateData(), event: event)
    }

}

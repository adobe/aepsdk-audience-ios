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

import AEPServices
import AEPCore
import AEPIdentity
import Foundation

/// @class AudienceState
/// 1. Responsible for keeping the current state of all Audience-related variables.
/// 2. Persists variables via the NamedCollectionDataStore.
/// 3. Provides public getters and setters for all maintained variables.
public class AudienceState {
    private static let LOG_TAG = "AudienceState"
    /// The Audience Manager extension datastore.
    private var dataStore: NamedCollectionDataStore
    /// The Audience Manager Data Source ID.
    private var dpid = String()
    /// The Audience Manager Data Provider Unique User ID.
    private var dpuuid = String()
    /// The Audience Manager Unique User ID
    private var uuid = String()
    /// The Audience Manager Visitor Profile
    private var visitorProfile = [String: String]()
    /// The current privacy status provided by the Configuration extension, defaults to `unknown`
    private var privacyStatus: PrivacyStatus
    /// The Audience Manager Analytics forwarding enabled status provided by the Configuration extension
    private var aamForwardingStatus = false
    /// The Audience Manager server provided by the Configuration extension
    private var aamServer = String()
    /// The Audience Manager timeout provided by the Configuration extension
    private var aamTimeout = TimeInterval()
    /// The Experience Cloud Org ID provided by the Configuration extension
    private var orgId = String()
    /// The Experience Cloud ID provided by the Identity extension
    private var ecid = String()
    /// The Experience Cloud ID service blob value provided by the Identity extension
    private var blob = String()
    /// The Experience Cloud ID service location hint provided by the Identity extension
    private var locationHint = String()
    ///  The synced visitor ID's provided by the Identity extension
    private var syncedVisitorIds = [CustomIdentity]()
    /// The customer event data present in an event triggering a signalWithData hit
    private var customerEventData = [String: String]()

    private(set) var hitQueue: HitQueuing

    /// Creates a new `AudienceState`
    init(hitQueue: HitQueuing) {
        dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)
        privacyStatus = .unknown
        self.hitQueue = hitQueue
    }

    // MARK: Public methods

    /// Queues an AAM hit with the passed in event data then dispatches a response event with the visitorProfile
    /// - Parameters:
    ///   - event: the event to version the shared state at
    ///   - dispatchResponse: a function which when invoked dispatches a response `Event` with the visitor profile to the `EventHub`
    func queueHit(event: Event, dispatchResponse: ([String:String], Event) -> Void) {
        if privacyStatus == PrivacyStatus.optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process AAM event as privacy status is opted-out:  \(event.description)")
            // dispatch with an empty visitor profile in response if privacy is opt-out.
            dispatchResponse([:], event)
            return
        }

        if privacyStatus == PrivacyStatus.unknown {
            Log.debug(label: getLogTagWith(functionName: #function), "Queueing the Audience Hit, privacy status is unknown:  \(event.description)")
            // dispatch with an empty visitor profile in response if privacy is unknown.
            dispatchResponse([:], event)
        }

        // if the event is a lifecycle event, convert the lifecycle keys to audience manager keys
        if event.type == EventType.lifecycle {
            customerEventData = convertLifecycleKeys(event: event)
        } else {
            if let signalData = event.data, !signalData.isEmpty {
                let signaledTraits = signalData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] as? [String : String] ?? [:]
                for trait in signaledTraits {
                    customerEventData[trait.key] = trait.value
                }
            }
        }

        guard let url = URL.buildAudienceHitURL(state: self) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Dropping Audience hit, failed to create hit URL")
            return
        }

        guard let hitData = try? JSONEncoder().encode(AudienceHit(url: url, timeout: getAamTimeout(), event: event)) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Dropping Audience hit, failed to encode AudienceHit")
            return
        }

        hitQueue.queue(entity: DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: hitData))
    }

    /// Sends an opt-out hit to the configured Audience Manager server
    func sendOptOutHit() {
        if aamServer.isEmpty { return }

        // only send the opt-out hit if the audience manager server and uuid are not empty
        if !getUuid().isEmpty && !aamServer.isEmpty {
            ServiceProvider.shared.networkService.sendOptOutRequest(aamServer: aamServer, uuid: uuid)
        }
    }

    /// Invoked by the Audience Manager extension each time we receive a network response for a processed hit
    /// - Parameters:
    ///   - hit: the hit that was processed
    ///   - responseData: the response data if any
    ///   - dispatchResponse: a function which when invoked dispatches a response `Event` with the visitor profile to the `EventHub`
    ///   - createSharedState: a function which when invoked creates a shared state for the Audience Manager extension
    func handleHitResponse(hit: AudienceHit, responseData: Data?, dispatchResponse: ([String:String], Event) -> Void, createSharedState: (([String: Any], Event) -> Void)) {
        if privacyStatus == .optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Unable to process network response as privacy status is OPT_OUT.")
            return
        }

        // if we have no response from the audience server log it and bail early
        if responseData == nil {
            Log.debug(label: getLogTagWith(functionName: #function), "No response from the server.")
            createSharedState(getStateData(), hit.event)
            dispatchResponse(getVisitorProfile(), hit.event)
            return
        }

        // process the response data from the audience hit
        processResponseData(event: hit.event, response: responseData ?? Data())

        // update audience manager shared state
        createSharedState(getStateData(), hit.event)

        // dispatch the updated visitor profile in response.
        dispatchResponse(getVisitorProfile(), hit.event)
    }

    /// Processes a response from the Audience Manager server or Analytics extension. This function attempts to forward any necessary requests found in the AAM "dests" array, and to create a dictionary out of the contents of the "stuff" array.
    /// - Parameters:
    ///   - event: the response event to be processed
    ///   - response: the JSON response received
    func processResponseData(event: Event, response: Data) {
        // bail if we don't have an audience manager server from configuration yet
        if aamServer.isEmpty { return }
        // quick out if privacy somehow became opted out after receiving a network response
        if privacyStatus == .optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Will not process the network response as privacy is opted-out.")
            return
        }

        // if we have an error decoding the response, log it and bail early
        guard let audienceResponse = try? JSONDecoder().decode(AudienceHitResponse.self, from: response) else {
            Log.debug(label: getLogTagWith(functionName: #function), "Failed to decode Audience Manager response.")
            return
        }

        // process dests array
        processDestsArray(response: audienceResponse, timeout: getAamTimeout())

        // save uuid for use with subsequent calls
        let uuid = audienceResponse.uuid ?? ""
        setUuid(uuid: uuid)

        // process stuff array
        let processedStuff = processStuffArray(stuff: audienceResponse.stuff ?? [AudienceStuffObject]())

        if !processedStuff.isEmpty {
            Log.trace(label: getLogTagWith(functionName: #function), "Stuff in response received: \(processedStuff).")
        } else {
            Log.trace(label: getLogTagWith(functionName: #function), "Stuff in response was empty.")
        }

        // save profile in defaults
        setVisitorProfile(visitorProfile: processedStuff)
    }

    /// Extracts the configuration settings from the passed in configuration shared state and caches them in the AudienceState instance.
    /// - Parameter:
    ///   - event: The configuration response content event
    ///   - configSharedState: the configuration shared state data
    ///   - createSharedState: a function which when invoked creates a shared state for the Audience Manager extension
    func handleConfigurationSharedStateUpdate(event: Event, configSharedState: [String: Any], createSharedState: (([String: Any], Event) -> Void)) {
        // store configuration settings that the audience manager extension needs
        if let aamServer = configSharedState[AudienceConstants.Configuration.AAM_SERVER] as? String, !aamServer.isEmpty {
            setAamServer(server: aamServer)
        }
        if let aamTimeout = configSharedState[AudienceConstants.Configuration.AAM_TIMEOUT] as? TimeInterval {
            setAamTimeout(timeout: aamTimeout)
        }
        if let aamForwardingStatus = configSharedState[AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING] as? Bool {
            setAamForwardingStatus(status: aamForwardingStatus)
        }
        if let orgId = configSharedState[AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID] as? String {
            setOrgId(orgId: orgId)
        }
        // get the privacy status
        guard let privacyStatusStr = configSharedState[AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String else { return }
        let privacyStatus = PrivacyStatus(rawValue: privacyStatusStr) ?? PrivacyStatus.unknown
        // if privacy is opted out: send the opt out hit, clear the audience state, then create a new audience shared state
        if privacyStatus == .optedOut {
            Log.debug(label: getLogTagWith(functionName: #function), "Privacy status is opted-out. Queued Audience hits and stored Audience Identifiers will be cleared.")
            sendOptOutHit()
            setMobilePrivacy(status: privacyStatus)
            createSharedState(getStateData(), event)
            return
        }

        // if privacy status is opted out, audience manager data in the AudienceState will be cleared.
        setMobilePrivacy(status: privacyStatus)
    }

    /// Extracts the identity variavles from the passed in identity shared state and caches them in the AudienceState instance.
    /// - Parameter:
    ///   - identitySharedState: the identity shared state data
    func handleIdentitySharedStateUpdate(identitySharedState: [String: Any]) {
        if let ecid = identitySharedState[AudienceConstants.Identity.VISITOR_ID_MID] as? String {
            setEcid(ecid: ecid)
        }
        if let blob = identitySharedState[AudienceConstants.Identity.VISITOR_ID_BLOB] as? String {
            setBlob(blob: blob)
        }
        if let locationHint = identitySharedState[AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT] as? String {
            setLocationHint(locationHint: locationHint)
        }
        if let syncedVisitorIds = identitySharedState[AudienceConstants.Identity.VISITOR_IDS_LIST] as? [CustomIdentity] {
            setVisitorIds(visitorIds: syncedVisitorIds)
        }
    }

    // Mark: setters

    /// Sets the value of the dpid property in the AudienceState instance.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - dpid: The value for the new dpid
    func setDpid(dpid: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.dpid = dpid
    }

    /// Sets the value of the dpuuid property in the AudienceState instance.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - dpuuid: The value for the new dpuuid
    func setDpuuid(dpuuid: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.dpuuid = dpuuid
    }

    /// Sets the value of the uuid property in the AudienceState instance.
    /// The new value is persisted in the datastore.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - uuid: The value for the new uuid
    func setUuid(uuid: String) {
        if privacyStatus == .optedOut {
            return
        } else if uuid.isEmpty {
            dataStore.remove(key: AudienceConstants.DataStoreKeys.USER_ID_KEY)
        } else {
            dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID_KEY, value: uuid)
        }

        self.uuid = uuid
    }

    /// Sets the value of the visitor profile property in the AudienceState instance.
    /// The new value is persisted in the datastore.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - visitorProfile: The value for the new visitorProfile
    func setVisitorProfile(visitorProfile: [String: String]) {
        if privacyStatus == .optedOut {
            return
        } else if visitorProfile.isEmpty {
            dataStore.remove(key: AudienceConstants.DataStoreKeys.PROFILE_KEY)
        } else {
            dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE_KEY, value: visitorProfile)
        }

        self.visitorProfile = visitorProfile
    }

    /// Sets the `PrivacyStatus` in the AudienceState instance.
    /// If the `PrivacyStatus` is `PrivacyStatus.optedOut`, any stored identifiers are cleared.
    /// - Parameter:
    ///   - status: The value for the new privacyStatus
    func setMobilePrivacy(status: PrivacyStatus) {
        self.privacyStatus = status
        if privacyStatus == .optedOut {
            clearIdentifiers()
        }
        // update hit queue with privacy status
        hitQueue.handlePrivacyChange(status: privacyStatus)
    }

    /// Sets the audience manager analytics forwarding enabled status in the AudienceState instance.
    /// Setting the forwarding status is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - status: The value for the new audience manager analytics forwarding enabled status
    func setAamForwardingStatus(status: Bool) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.aamForwardingStatus = status
    }

    /// Sets the audience server in the AudienceState instance.
    /// Setting the audience server is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - server: The value for the new server
    func setAamServer(server: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.aamServer = server
    }

    /// Sets the audience timeout in the AudienceState instance.
    /// Setting the audience timeout is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - timeout: The value for the new timeout
    func setAamTimeout(timeout: TimeInterval) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.aamTimeout = timeout
    }

    /// Sets the experience cloud org id in the AudienceState instance.
    /// Setting the experience cloud org id is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - orgId: The value for the new orgId
    func setOrgId(orgId: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.orgId = orgId
    }

    /// Sets the experience cloud id in the AudienceState instance.
    /// Setting the experience cloud id is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - ecid: The value for the new ecid
    func setEcid(ecid: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.ecid = ecid
    }

    /// Sets the experience cloud blob in the AudienceState instance.
    /// Setting the experience cloud blob is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - blob: The value for the new blob
    func setBlob(blob: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.blob = blob
    }

    /// Sets the experience cloud location hint in the AudienceState instance.
    /// Setting the experience cloud location hint is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - locationHint: The value for the new location hint
    func setLocationHint(locationHint: String) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.locationHint = locationHint
    }

    /// Sets the visitor id list in the AudienceState instance.
    /// Setting the visitor id list is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - visitorIds: The value for the new synced visitor ids
    func setVisitorIds(visitorIds: [CustomIdentity]) {
        // allow setting if not opt-out
        if privacyStatus == .optedOut {
            return
        }
        self.syncedVisitorIds = visitorIds
    }

    // MARK: getters

    /// Returns the `dpid` from the AudienceState instance.
    /// - Returns: A string containing the `dpid`
    func getDpid() -> String {
        return self.dpid
    }

    /// Returns the `dpuuid` from the AudienceState instance.
    /// - Returns: A string containing the `dpuuid`
    func getDpuuid() -> String {
        return self.dpuuid
    }

    /// Returns the `uuid` from the AudienceState instance.
    /// If there is no `uuid` value in memory, this method attempts to find one from the DataStore.
    /// - Returns: A string containing the `uuid`
    func getUuid() -> String {
        if self.uuid.isEmpty {
            // check data store to see if we can return a uuid from persistence
            self.uuid = dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID_KEY) ?? ""
        }
        return self.uuid
    }

    /// Returns the `visitorProfile` from the AudienceState instance.
    /// If there is no `visitorProfile` value in memory, this method attempts to find one from the DataStore.
    /// - Returns: A dictionary containing the `visitorProfile`
    func getVisitorProfile() -> [String: String] {
        if self.visitorProfile.isEmpty {
            // check data store to see if we can return a visitor profile from persistence
            self.visitorProfile = (dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE_KEY)) as? [String: String] ?? [String: String]()
        }
        return self.visitorProfile
    }

    /// Returns the `PrivacyStatus` from the AudienceState instance.
    /// - Returns: The `PrivacyStatus` stored in the AudienceState
    func getPrivacyStatus() -> PrivacyStatus {
        return self.privacyStatus
    }

    /// Returns the aam forwarding enabled status from the AudienceState instance.
    /// - Returns: A boolean containing the aam forwarding status
    func getAamForwardingStatus() -> Bool {
        return self.aamForwardingStatus
    }

    /// Returns the audience manager server from the AudienceState instance.
    /// - Returns: A string containing the audience manager server
    func getAamServer() -> String {
        return self.aamServer
    }

    /// Returns the audience manager timeout from the AudienceState instance.
    /// - Returns: A `TimeInterval` containing the audience manager timeout
    func getAamTimeout() -> TimeInterval {
        if self.aamTimeout <= 0 {
            return AudienceConstants.Default.TIMEOUT
        }
        return self.aamTimeout
    }

    /// Returns the experience cloud org id from the AudienceState instance.
    /// - Returns: A string containing the experience cloud org id
    func getOrgId() -> String {
        return self.orgId
    }

    /// Returns the experience cloud id from the AudienceState instance.
    /// - Returns: A string containing the experience cloud id
    func getEcid() -> String {
        return self.ecid
    }

    /// Returns the experience cloud blob from the AudienceState instance.
    /// - Returns: A string containing the experience cloud blob
    func getBlob() -> String {
        return self.blob
    }

    /// Returns the experience cloud location hint from the AudienceState instance.
    /// - Returns: A string containing the experience cloud location hint
    func getLocationHint() -> String {
        return self.locationHint
    }

    /// Returns the experience cloud visitor id list from the AudienceState instance.
    /// - Returns: An array containing the synced visitor ids
    func getVisitorIds() -> [CustomIdentity] {
        return self.syncedVisitorIds
    }

    /// Returns the customer event data from the AudienceState instance.
    /// - Returns: A dictionary containing the customer event data present in the signalWithData event
    func getCustomerEventData() -> [String: String] {
        return self.customerEventData
    }

    /// Get the data for this AudienceState instance to share with other extensions.
    /// The state data is only populated if the set privacy status is not `PrivacyStatus.optedOut`.
    /// - Returns: A dictionary containing the event data stored in the AudienceState
    func getStateData() -> [String: Any] {
        var data = [String: Any]()
        if privacyStatus != .optedOut {
            let dpid = getDpid()
            if !dpid.isEmpty {
                data[AudienceConstants.EventDataKeys.DPID] = dpid
            }

            let dpuuid = getDpuuid()
            if !dpuuid.isEmpty {
                data[AudienceConstants.EventDataKeys.DPUUID] = dpuuid
            }

            let visitorProfile = getVisitorProfile()
            if !visitorProfile.isEmpty {
                data[AudienceConstants.EventDataKeys.VISITOR_PROFILE] = visitorProfile
            }

            let uuid = getUuid()
            if !uuid.isEmpty {
                data[AudienceConstants.EventDataKeys.UUID] = uuid
            }
        }
        return data
    }

    // MARK: helpers

    /// Clear the identifiers and cached shared states for this AudienceState.
    /// The cleared Audience Manager identifiers are: `uuid`, `dpid`, `dpuuid`, and `visitorProfile`
    func clearIdentifiers() {
        // clear the persisted data
        dataStore.remove(key: AudienceConstants.DataStoreKeys.USER_ID_KEY)
        dataStore.remove(key: AudienceConstants.DataStoreKeys.PROFILE_KEY)
        // reset the in-memory audience manager variables
        self.uuid = ""
        self.dpuuid = ""
        self.dpid = ""
        self.visitorProfile = [:]
        // clear configuration and identity variables if privacy is opted out
        if privacyStatus == .optedOut {
            self.aamServer = ""
            self.aamTimeout = AudienceConstants.Default.TIMEOUT
            self.orgId = ""
            self.ecid = ""
            self.blob = ""
            self.locationHint = ""
            self.syncedVisitorIds = []
            self.customerEventData = [:]
        }
    }

    /// Helper to return a log tag
    /// - Parameters:
    ///   - functionName: the function name to be used in generating a log tag
    private func getLogTagWith(functionName: String) -> String {
        return "\(AudienceState.LOG_TAG):\(functionName)"
    }

    /// Converts Lifecycle event data to Audience Manager context data
    /// - Parameters:
    ///   - event: the `Lifecycle` response content event
    private func convertLifecycleKeys(event: Event) -> [String: String] {
        var convertedKeys = [String: String]()
        let lifecycleEventData = event.data as? [String:String]

        // convert the found event data keys into context data keys
        // each pairedKey object has an event data key as a key and a context data key as a value
        for pairedKey in AudienceConstants.MapToContextDataKeys {
            guard let value = lifecycleEventData?[pairedKey.key] else {
                Log.trace(label: getLogTagWith(functionName: #function), "\(pairedKey.key) not found in lifecycle context data.")
                continue
            }
            convertedKeys[pairedKey.value] = value
        }

        return convertedKeys
    }

    /// Parses the "dests" array present in the Audience Manager response and forwards data to the url's found.
    /// - Parameters:
    ///   - response: the `AudienceHitResponse` if any
    ///   - timeout: the Audience Manager network request timeout
    private func processDestsArray(response: AudienceHitResponse, timeout: TimeInterval) {
        // bail if the dests array is not present in the response
        guard let destinations: [[String:String]] = response.dests else {
            Log.debug(label: getLogTagWith(functionName: #function), "No destinations found in response.")
            return
        }

        for destination in destinations {
            guard let url = URL(string: destination[AudienceConstants.ResponseKeys.JSON_URL_KEY] ?? "") else {
                Log.error(label: getLogTagWith(functionName: #function), "Building destination URL failed, skipping forwarding for: \(String(describing: destination[AudienceConstants.ResponseKeys.JSON_DESTS_KEY])).")
                continue
            }
            Log.debug(label: getLogTagWith(functionName: #function), "Forwarding to url: \(url).")
            let networkRequest = NetworkRequest(url: url, httpMethod: .get, connectPayload: "", httpHeaders: [String: String](), connectTimeout: timeout, readTimeout: timeout)
            ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest, completionHandler: nil) // fire and forget
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
                    Log.debug(label: getLogTagWith(functionName: #function), "Error processing stuff object with cookie name \(String(describing: stuffObject.cookieKey)).")
                    continue
                }
                guard let value = stuffObject.cookieValue else {
                    Log.debug(label: getLogTagWith(functionName: #function), "Error processing stuff object with cookie value \(String(describing: stuffObject.cookieValue)).")
                    continue
                }
                segments[key] = value
            }
        } else {
            Log.debug(label: getLogTagWith(functionName: #function), "No `stuff` array found in response.")
        }

        return segments
    }
}

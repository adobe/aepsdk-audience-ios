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
import Foundation

/// @class AudienceState
/// 1. Responsible for keeping the current state of all Audience-related variables.
/// 2. Persists variables via the LocalStorageServiceInterface.
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
    private var visitorProfile = [String:String]()
    /// The current privacy status provided by the Configuration extension, defaults to `unknown`
    private var privacyStatus: PrivacyStatus
    
    /// Creates a new `AudienceState`
    init() {
        dataStore = NamedCollectionDataStore(name: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_DATA_STORE)
        privacyStatus = .unknown
    }
    
    //==================================================================
    // public methods
    //==================================================================
    
    /// Sets the value of the dpid property in the AudienceState instance.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - dpid: The value for the new dpid
    func setDpid(dpid:String) {
        // allow setting if not opt-out or if clearing data
        if(dpid.isEmpty || privacyStatus != .optedOut){
            self.dpid = dpid
        }
    }
    
    /// Sets the value of the dpuuid property in the AudienceState instance.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - dpuuid: The value for the new dpuuid
    func setDpuuid(dpuuid:String) {
        // allow setting if not opt-out or if clearing data
        if(dpuuid.isEmpty || privacyStatus != .optedOut){
            self.dpuuid = dpuuid
        }
    }
    
    /// Sets the value of the uuid property in the AudienceState instance.
    /// The new value is persisted in the datastore.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - uuid: The value for the new uuid
    func setUuid(uuid:String) {
        if(privacyStatus == .optedOut) {
            return
        }
        else if(uuid.isEmpty){
            dataStore.remove(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY)
        }
        else {
            dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, value: uuid)
        }

        self.uuid = uuid
    }
    
    /// Sets the value of the visitor profile property in the AudienceState instance.
    /// The new value is persisted in the datastore.
    /// Setting the identifier is ignored if the global privacy is set to `PrivacyStatus.optedOut`.
    /// - Parameter:
    ///   - visitorProfile: The value for the new visitorProfile
    func setVisitorProfile(visitorProfile:[String: String]) {
        if(privacyStatus == .optedOut) {
            return
        }
        else if(visitorProfile.isEmpty){
            dataStore.remove(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY)
        }
        else {
            dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, value: visitorProfile)
        }

        self.visitorProfile = visitorProfile
    }
    
    /// Sets the `PrivacyStatus` in the AudienceState instance.
    /// If the `PrivacyStatus` is `PrivacyStatus.optedOut`, any stored identifiers are cleared.
    /// - Parameter:
    ///   - privacyStatus: The value for the new privacyStatus
    func setMobilePrivacyStatus(privacyStatus: PrivacyStatus) {
        self.privacyStatus = privacyStatus
        if(privacyStatus == .optedOut){
            clearIdentifiers()
        }
    }
    
    //==================================================================
    // getters
    //==================================================================
    
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
        if(self.uuid.isEmpty){
            // check data store to see if we can return a uuid from persistence
            self.uuid = dataStore.getString(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY) ?? ""
        }
        return self.uuid
    }
    
    /// Returns the `visitorProfile` from the AudienceState instance.
    /// If there is no `visitorProfile` value in memory, this method attempts to find one from the DataStore.
    /// - Returns: A dictionary containing the `visitorProfile`
    func getVisitorProfile() -> [String:String] {
        if(self.visitorProfile.isEmpty){
            // check data store to see if we can return a visitor profile from persistence
            self.visitorProfile = (dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY)) as? [String:String] ?? [String:String]()
        }
        return self.visitorProfile
    }
    
    /// Returns the `PrivacyStatus` from the AudienceState instance.
    /// - Returns: The `PrivacyStatus` stored in the AudienceState
    func getPrivacyStatus() -> PrivacyStatus {
        return self.privacyStatus
    }
    
    /// Get the data for this AudienceState instance to share with other modules.
    /// The state data is only populated if the set privacy status is not `PrivacyStatus.optedOut`.
    /// - Returns: A dictionary containing the event data stored in the AudienceState
    func getStateData() -> [String:Any] {
        var data = [String:Any]()
        if(privacyStatus != .optedOut){
            let dpid = getDpid()
            if(!dpid.isEmpty){
                data[AudienceConstants.EventDataKeys.DPID] = dpid
            }
            
            let dpuuid = getDpuuid()
            if(!dpuuid.isEmpty){
                data[AudienceConstants.EventDataKeys.DPUUID] = dpuuid
            }
            
            let visitorProfile = getVisitorProfile()
            if(!visitorProfile.isEmpty){
                data[AudienceConstants.EventDataKeys.VISITOR_PROFILE] = visitorProfile
            }
            
            let uuid = getUuid()
            if(!uuid.isEmpty){
                data[AudienceConstants.EventDataKeys.UUID] = uuid
            }
        }
        return data
    }
    
    /// Clear the identifiers for this AudienceState.
    /// The cleared identifiers are: `uuid`, `dpid`, `dpuuid`, and `visitorProfile`
    func clearIdentifiers() {
        // clear the persisted data
        dataStore.remove(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY)
        dataStore.remove(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY)
        // reset the in-memory variables
        self.uuid = ""
        self.dpuuid = ""
        self.dpid = ""
        self.visitorProfile = [String:String]()
    }
}

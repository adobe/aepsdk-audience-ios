  
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
public final class AudienceState {
    private static let LOG_TAG = "AudienceState"
    let dataStore: NamedCollectionDataStore
    private var dpid = String()
    private var dpuuid = String()
    private var uuid = String()
    private var visitor_profile = [String: String]()
    private var privacy_status = PrivacyStatus.unknown
    
    /// Creates a new `AudienceState`
    /// - Parameter:
    ///   - dataStore: The Audience Extension's datastore
    init(dataStore: NamedCollectionDataStore) {
        self.dataStore = dataStore
    }
    
    func setDpid(dpid:String) {
        if(!dpid.isEmpty && privacy_status != PrivacyStatus.optedOut){
            self.dpid = dpid;
        }
    }
    
    func setDpuuid(dpuuid:String) {
        if(!dpuuid.isEmpty && privacy_status != PrivacyStatus.optedOut){
            self.dpuuid = dpuuid;
        }
    }
    
    func setUuid(uuid:String) {
        if(uuid.isEmpty){
            dataStore.remove(key: AudienceConstants.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY)
        }else if(privacy_status != PrivacyStatus.optedOut){
            dataStore.set(key: AudienceConstants.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, value: uuid)
            self.uuid = uuid;
        }
    }
    
    func setVisitorProfile(visitorProfile:[String: String]) {
        if(visitorProfile.isEmpty){
            dataStore.remove(key: AudienceConstants.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY)
        }else if(privacy_status != PrivacyStatus.optedOut){
            dataStore.set(key: AudienceConstants.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, value: visitorProfile)
            self.visitor_profile = visitorProfile
        }
    }
}

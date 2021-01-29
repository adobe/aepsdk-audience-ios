/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import AEPServices

public class AudienceMigrator {
    private static let LOG_TAG = "AudienceMigrator"
    
    private static var userDefaults: UserDefaults {
        if let appGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !appGroup.isEmpty {
            return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }
        
    /// Migrate audience data from v4 local storage
    /// - Parameters:
    ///   - dataStore: DataStore to store persisted audience data
    private static func migrateFromV4(dataStore: NamedCollectionDataStore){
        if let uuid = userDefaults.string(forKey: AudienceConstants.V4Migration.USER_ID) {
            Log.trace(label: AudienceMigrator.LOG_TAG, "Migration started for Audience Manager data from V4.")
            dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID, value: uuid)
            
            userDefaults.removeObject(forKey: AudienceConstants.V4Migration.USER_ID)
            userDefaults.removeObject(forKey: AudienceConstants.V4Migration.PROFILE)
            Log.trace(label: AudienceMigrator.LOG_TAG, "Migration complete for Audience Manager data from V4.")
        }
    }
    
    /// Migrate audience data from v5 local storage
    /// - Parameters:
    ///   - dataStore: DataStore to store persisted audience data
    private static func migrateFromV5(dataStore: NamedCollectionDataStore){
        if let uuid = userDefaults.string(forKey: AudienceConstants.V5Migration.USER_ID) {
            Log.trace(label: AudienceMigrator.LOG_TAG, "Migration started for Audience Manager data from V5.")
            
            dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID, value: uuid)
            if let profileData = userDefaults.dictionary(forKey: AudienceConstants.V5Migration.PROFILE) {
                dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE, value: profileData)
            }
            
            userDefaults.removeObject(forKey: AudienceConstants.V5Migration.USER_ID)
            userDefaults.removeObject(forKey: AudienceConstants.V5Migration.PROFILE)
            Log.trace(label: AudienceMigrator.LOG_TAG, "Migration complete for Audience Manager data from V5.")
        }
    }

    /// Migrate audience data from v4 & v5 local storage
    /// - Parameters:
    ///   - dataStore: DataStore to store persisted audience data
    static func migrateLocalStorage(dataStore: NamedCollectionDataStore) {
        migrateFromV4(dataStore: dataStore)
        migrateFromV5(dataStore: dataStore)
    }
}

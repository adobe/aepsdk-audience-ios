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

@testable import AEPCore
@testable import AEPServices
@testable import AEPAudience
import XCTest

class AudienceMigratorTests: XCTestCase {

    var audience: Audience!
    var dataStore: NamedCollectionDataStore!

    private var mockDataStore: MockDataStore {
        return ServiceProvider.shared.namedKeyValueService as! MockDataStore
    }

    private var userDefaults: UserDefaults {
        if let appGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !appGroup.isEmpty {
            return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    override func setUp() {
        UserDefaults.clear()

        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        MobileCore.setLogLevel(.error) // reset log level to error before each test
        dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)
    }

    func testAAMMigrationNoData() {
        AudienceMigrator.migrateLocalStorage(dataStore: dataStore)

        // Nothing should be migrated
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.USER_ID))
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.PROFILE))
    }

    func testAAMMigrationFromV4() {
        userDefaults.set("uuid", forKey: AudienceConstants.V4Migration.USER_ID)
        userDefaults.set(["k1": "v1", "k2": "v2"], forKey: AudienceConstants.V4Migration.PROFILE)

        AudienceMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertNil(userDefaults.object(forKey: AudienceConstants.V4Migration.USER_ID))
        XCTAssertNil(userDefaults.object(forKey: AudienceConstants.V4Migration.PROFILE))

        // Only migrate uuid from v4.
        XCTAssertEqual("uuid", dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID))
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.PROFILE))
    }

    func testAAMMigrationFromV5() {
        userDefaults.set("uuid", forKey: AudienceConstants.V5Migration.USER_ID)
        userDefaults.set(["k1": "v1", "k2": "v2"], forKey: AudienceConstants.V5Migration.PROFILE)

        AudienceMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertNil(userDefaults.object(forKey: AudienceConstants.V5Migration.USER_ID))
        XCTAssertNil(userDefaults.object(forKey: AudienceConstants.V5Migration.PROFILE))

        // Migrate both uuid and profile from v5
        XCTAssertEqual("uuid", dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID))
        XCTAssertEqual(["k1": "v1", "k2": "v2"], dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE) as? [String: String])
    }

    func testAAMMigrationFromV5InAppGroup() {

        mockDataStore.setAppGroup("test-app-group")

        userDefaults.set("uuid", forKey: AudienceConstants.V5Migration.USER_ID)
        userDefaults.set(["k1": "v1", "k2": "v2"], forKey: AudienceConstants.V5Migration.PROFILE)

        AudienceMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertNil(userDefaults.object(forKey: AudienceConstants.V5Migration.USER_ID))
        XCTAssertNil(userDefaults.object(forKey: AudienceConstants.V5Migration.PROFILE))

        // Migrate both uuid and profile from v5
        XCTAssertEqual("uuid", dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID))
        XCTAssertEqual(["k1": "v1", "k2": "v2"], dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE) as? [String: String])
    }
}

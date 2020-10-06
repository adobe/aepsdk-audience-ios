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

import XCTest
@testable import AEPAudience
@testable import AEPCore
@testable import AEPServices

class AudienceStateTests: XCTestCase {
    let dataStore = NamedCollectionDataStore(name: "AudienceStateTests")
    var audienceState: AudienceState!
    // test strings
    static let emptyString = ""
    static let emptyProfile = [String:String]()
    static let inMemoryDpid = "inMemoryDpid"
    static let inMemoryDpuuid = "inMemoryDpuuid"
    static let inMemoryUuid = "inMemoryUuid"
    static let persistedUuid = "persistedUuid"
    static let inMemoryVisitorProfile = ["inMemoryTrait":"inMemoryValue"]
    static let persistedVisitorProfile = ["persistedTrait":"persistedValue"]
    
    override func setUp() {
        MobileCore.setLogLevel(level: .error) // reset log level to error before each test
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        audienceState = AudienceState(dataStore: dataStore)
    }

    func testGetDpid_WhenDpidEmptyInMemory() {
        // setup
        audienceState.setDpid(dpid: AudienceStateTests.emptyString)
        
        // test
        let returnedValue = audienceState.getDpid()
        
        // verify
        XCTAssertTrue(returnedValue.isEmpty)
    }
    
    func testGetDpid_WhenDpidValueInMemory() {
        // setup
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        
        // test
        let returnedValue = audienceState.getDpid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpid, returnedValue)
    }
    
    func testGetDpuuid_WhenDpuuidEmptyInMemory() {
        // setup
        audienceState.setDpuuid(dpuuid: AudienceStateTests.emptyString)
        
        // test
        let returnedValue = audienceState.getDpuuid()
        
        // verify
        XCTAssertTrue(returnedValue.isEmpty)
    }
    
    func testGetDpuuid_WhenDpuuidValueInMemory() {
        // setup
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        
        // test
        let returnedValue = audienceState.getDpuuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpuuid, returnedValue)
    }
    
    func testGetUuid_WhenUuidEmptyInMemoryAndPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, value: AudienceStateTests.emptyString)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertTrue(returnedValue.isEmpty)
    }
    
    func testGetUuid_WhenUuidValueEmptyInMemoryAndValueInPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, value: AudienceStateTests.persistedUuid)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.persistedUuid, returnedValue)
    }
    
    func testGetUuid_WhenUuidValueInMemoryAndValueEmptyInPersistence() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, value: AudienceStateTests.emptyString)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, returnedValue)
    }
    
    func testGetUuid_WhenUuidValueInMemoryAndValueInPersistence() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, value: AudienceStateTests.persistedUuid)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, returnedValue)
    }
    
    func testGetVisitorProfile_WhenVisitorProfileEmptyInMemoryAndPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, value: AudienceStateTests.emptyProfile)
        
        // test
        let returnedValue = audienceState.getVisitorProfile() 
        
        // verify
        XCTAssertTrue(returnedValue.isEmpty)
    }
    
    func testGetVisitorProfile_WhenVisitorProfileEmptyInMemoryAndValueInPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, value: AudienceStateTests.persistedVisitorProfile)
        
        // test
        let returnedValue = audienceState.getVisitorProfile()
        
        // verify
        XCTAssertFalse(returnedValue.isEmpty)
        XCTAssertEqual(1, returnedValue.count)
        XCTAssertEqual(AudienceStateTests.persistedVisitorProfile, returnedValue)
    }
    
    func testGetVisitorProfile_WhenVisitorProfileValueInMemoryAndValueEmptyInPersistence() {
        // setup
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, value: AudienceStateTests.emptyProfile)
        
        // test
        let returnedValue = audienceState.getVisitorProfile()
        
        // verify
        XCTAssertFalse(returnedValue.isEmpty)
        XCTAssertEqual(1, returnedValue.count)
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, returnedValue)
    }
    
    func testGetVisitorProfile_WhenVisitorProfileValueInMemoryAndValueInPersistence() {
        // setup
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        dataStore.set(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, value: AudienceStateTests.persistedVisitorProfile)
        
        // test
        let returnedValue = audienceState.getVisitorProfile()
        
        // verify
        XCTAssertFalse(returnedValue.isEmpty)
        XCTAssertEqual(1, returnedValue.count)
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, returnedValue)
    }
    
    func testSetDpid_WithEmptyString() {
        // setup
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        
        // test
        audienceState.setDpid(dpid: AudienceStateTests.emptyString)
        
        // verify
        XCTAssertTrue(audienceState.getDpid().isEmpty)
    }
    
    func testSetDpid_WithValidString() {
        // setup
        audienceState.setDpid(dpid: AudienceStateTests.emptyString)
        
        // test
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpid, audienceState.getDpid())
    }
    
    func testSetDpid_WithPrivacyStatusOptedOut() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedOut)
        
        // test
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        
        // verify
        XCTAssertTrue(audienceState.getDpid().isEmpty)
    }
    
    func testSetDpid_WithPrivacyStatusUnknown() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.unknown)
        
        // test
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpid, audienceState.getDpid())
    }
    
    func testSetDpuuid_WithEmptyString() {
        // setup
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        
        // test
        audienceState.setDpuuid(dpuuid: AudienceStateTests.emptyString)
        
        // verify
        XCTAssertTrue(audienceState.getDpuuid().isEmpty)
    }
    
    func testSetDpuuid_WithValidString() {
        // setup
        audienceState.setDpuuid(dpuuid: AudienceStateTests.emptyString)
        
        // test
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpuuid, audienceState.getDpuuid())
    }
    
    func testSetDpuuid_WithPrivacyStatusOptedOut() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedOut)
        
        // test
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        
        // verify
        XCTAssertTrue(audienceState.getDpuuid().isEmpty)
    }
    
    func testSetDpuuid_WithPrivacyStatusUnknown() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.unknown)
        
        // test
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpuuid, audienceState.getDpuuid())
    }
    
    func testSetUuid_WithEmptyString() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.emptyString)
        
        // verify
        XCTAssertTrue(audienceState.getUuid().isEmpty)
        XCTAssertEqual(AudienceStateTests.emptyString, dataStore.getString(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, fallback: ""))
    }
    
    func testSetUuid_WithValidString() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.emptyString)
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, audienceState.getUuid())
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, dataStore.getString(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, fallback: ""))
    }
    
    func testSetUuid_WithPrivacyStatusOptedOut() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedOut)
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // verify
        XCTAssertTrue(audienceState.getUuid().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY))
    }
    
    func testSetUuid_WithPrivacyStatusUnknown() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.unknown)
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, audienceState.getUuid())
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, dataStore.getString(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY, fallback: ""))
    }
    
    func testSetVisitorProfile_WithEmptyDictionary() {
        // setup
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.emptyProfile)
        
        // verify
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertEqual(AudienceStateTests.emptyProfile, dataStore.getObject(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY, fallback: AudienceStateTests.emptyProfile))
    }
    
    func testSetVisitorProfile_WithValidDictionary() {
        // setup
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.emptyProfile)
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, audienceState.getVisitorProfile())
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, (dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY) as? [String : String] ?? AudienceStateTests.emptyProfile))
    }
    
    func testSetVisitorProfile_WithPrivacyStatusOptedOut() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedOut)
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // verify
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY))
    }
    
    func testSetVisitorProfile_WithPrivacyStatusUnknown() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.unknown)
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, audienceState.getVisitorProfile())
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, (dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY) as? [String : String] ?? AudienceStateTests.emptyProfile))
    }
    
    func testClearIdentifiers_Happy() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedIn)
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        audienceState.clearIdentifiers()
        
        // verify
        XCTAssertTrue(audienceState.getDpid().isEmpty)
        XCTAssertTrue(audienceState.getDpuuid().isEmpty)
        XCTAssertTrue(audienceState.getUuid().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY))
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY))
    }
    
    func testClearIdentifiers_CalledOnOptOut() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedIn)
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedOut)
        
        // verify
        XCTAssertTrue(audienceState.getDpid().isEmpty)
        XCTAssertTrue(audienceState.getDpuuid().isEmpty)
        XCTAssertTrue(audienceState.getUuid().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_USER_ID_KEY))
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_PROFILE_KEY))
    }
    
    func testGetStateData_Happy() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedIn)
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        let data = audienceState.getStateData()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryDpid, data[AudienceConstants.EventDataKeys.DPID] as? String ?? "")
        XCTAssertEqual(AudienceStateTests.inMemoryDpuuid, data[AudienceConstants.EventDataKeys.DPUUID] as? String ?? "")
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, data[AudienceConstants.EventDataKeys.UUID] as? String ?? "")
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, data[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String:String] ?? AudienceStateTests.emptyProfile)
    }
    
    func testGetStateData_EmptyDataOnOptedOut() {
        // setup
        audienceState.setMobilePrivacyStatus(privacyStatus: PrivacyStatus.optedOut)
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        let data = audienceState.getStateData()
        
        // verify
        XCTAssertEqual(AudienceStateTests.emptyString, data[AudienceConstants.EventDataKeys.DPID] as? String ?? "")
        XCTAssertEqual(AudienceStateTests.emptyString, data[AudienceConstants.EventDataKeys.DPUUID] as? String ?? "")
        XCTAssertEqual(AudienceStateTests.emptyString, data[AudienceConstants.EventDataKeys.UUID] as? String ?? "")
        XCTAssertEqual(AudienceStateTests.emptyProfile, data[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String:String] ?? AudienceStateTests.emptyProfile)
    }

}

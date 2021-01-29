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
@testable import AEPIdentity
@testable import AEPServices

class AudienceStateTests: XCTestCase {
    var dataStore : NamedCollectionDataStore!
    var audienceState: AudienceState!
    var mockHitQueue: MockHitQueue!
    var responseCallbackArgs = [(DataEntity, Data?)]()
    // test strings
    static let aamServer = "test.com"
    static let aamTimeout = TimeInterval(2)
    static let emptyString = ""
    static let emptyProfile = [String:String]()
    static let inMemoryDpid = "inMemoryDpid"
    static let inMemoryDpuuid = "inMemoryDpuuid"
    static let inMemoryUuid = "inMemoryUuid"
    static let persistedUuid = "persistedUuid"
    static let inMemoryVisitorProfile = ["inMemoryTrait":"inMemoryValue"]
    static let persistedVisitorProfile = ["persistedTrait":"persistedValue"]
    static let expectedVisitorProfile = ["cookie1":"cookieValue1","cookie2":"cookieValue2"]
    static let validConfigSharedState = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn, AudienceConstants.Configuration.AAM_SERVER: "www.testServer.com", AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING: false, AudienceConstants.Configuration.AAM_TIMEOUT: TimeInterval(10)] as [String: Any]
    static let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
    static let configEvent = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
    
    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        
        MobileCore.setLogLevel(.error) // reset log level to error before each test
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        mockHitQueue = MockHitQueue(processor: AudienceHitProcessor(responseHandler: { [weak self] entity, data in
            self?.responseCallbackArgs.append((entity, data))
        }))
        
        dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)
        audienceState = AudienceState(hitQueue: mockHitQueue, dataStore: dataStore)
    }
    
    override func tearDown() {
        // clear audience state by setting privacy to opt out
        audienceState.clearIdentifiers()
    }
    
    func optOut(shouldSendOptOutHit: Bool = false) {
        updatePrivacy(status: .optedOut, shouldUpdateSharedState: true, shouldSendOptOutHit: shouldSendOptOutHit)
    }
    
    func optIn() {
        updatePrivacy(status: .optedIn)
    }
    
    func optUknown() {
        updatePrivacy(status: .unknown)
    }
    
    func updatePrivacy(status: PrivacyStatus, shouldUpdateSharedState: Bool = false, shouldSendOptOutHit: Bool = false) {
        let configData = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: status.rawValue]
        let configEvent = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        audienceState.handlePrivacyStatusChange(event: configEvent, createSharedState: { (data, event) in
            if !shouldUpdateSharedState {
                XCTFail("Shared state should not be updated")
            }
        }, dispatchOptOutResult: { (optedOut, event) in
            if shouldSendOptOutHit != optedOut {
                XCTFail("Error sent optOutHit expected:\(shouldSendOptOutHit) actual:\(optedOut)")
            }
        })
    }

    // MARK: AudienceState unit tests
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
        dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID, value: AudienceStateTests.emptyString)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertTrue(returnedValue.isEmpty)
    }
    
    func testGetUuid_WhenUuidValueEmptyInMemoryAndValueInPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID, value: AudienceStateTests.persistedUuid)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.persistedUuid, returnedValue)
    }
    
    func testGetUuid_WhenUuidValueInMemoryAndValueEmptyInPersistence() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID, value: AudienceStateTests.emptyString)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, returnedValue)
    }
    
    func testGetUuid_WhenUuidValueInMemoryAndValueInPersistence() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID, value: AudienceStateTests.persistedUuid)
        
        // test
        let returnedValue = audienceState.getUuid()
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, returnedValue)
    }
    
    func testGetVisitorProfile_WhenVisitorProfileEmptyInMemoryAndPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE, value: AudienceStateTests.emptyProfile)
        
        // test
        let returnedValue = audienceState.getVisitorProfile() 
        
        // verify
        XCTAssertTrue(returnedValue.isEmpty)
    }
    
    func testGetVisitorProfile_WhenVisitorProfileEmptyInMemoryAndValueInPersistence() {
        // setup
        dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE, value: AudienceStateTests.persistedVisitorProfile)
        
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
        dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE, value: AudienceStateTests.emptyProfile)
        
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
        dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE, value: AudienceStateTests.persistedVisitorProfile)
        
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
        optOut()
        
        // test
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        
        // verify
        XCTAssertTrue(audienceState.getDpid().isEmpty)
    }
    
    func testSetDpid_WithPrivacyStatusUnknown() {
        // setup
        optUknown()
        
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
        optOut()
        
        // test
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        
        // verify
        XCTAssertTrue(audienceState.getDpuuid().isEmpty)
    }
    
    func testSetDpuuid_WithPrivacyStatusUnknown() {
        // setup
        optUknown()
        
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
        XCTAssertEqual(AudienceStateTests.emptyString, dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID, fallback: ""))
    }
    
    func testSetUuid_WithValidString() {
        // setup
        audienceState.setUuid(uuid: AudienceStateTests.emptyString)
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, audienceState.getUuid())
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID, fallback: ""))
    }
    
    func testSetUuid_WithPrivacyStatusOptedOut() {
        // setup
        optOut()
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // verify
        XCTAssertTrue(audienceState.getUuid().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.USER_ID))
    }
    
    func testSetUuid_WithPrivacyStatusUnknown() {
        // setup
        optUknown()
        
        // test
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, audienceState.getUuid())
        XCTAssertEqual(AudienceStateTests.inMemoryUuid, dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID, fallback: ""))
    }
    
    func testSetVisitorProfile_WithEmptyDictionary() {
        // setup
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.emptyProfile)
        
        // verify
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertEqual(AudienceStateTests.emptyProfile, dataStore.getObject(key: AudienceConstants.DataStoreKeys.PROFILE, fallback: AudienceStateTests.emptyProfile))
    }
    
    func testSetVisitorProfile_WithValidDictionary() {
        // setup
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.emptyProfile)
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, audienceState.getVisitorProfile())
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, (dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE) as? [String : String] ?? AudienceStateTests.emptyProfile))
    }
    
    func testSetVisitorProfile_WithPrivacyStatusOptedOut() {
        // setup
        optOut()
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // verify
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.PROFILE))
    }
    
    func testSetVisitorProfile_WithPrivacyStatusUnknown() {
        // setup
        optUknown()
        
        // test
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // verify
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, audienceState.getVisitorProfile())
        XCTAssertEqual(AudienceStateTests.inMemoryVisitorProfile, (dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE) as? [String : String] ?? AudienceStateTests.emptyProfile))
    }
    
    func testClearIdentifiers_Happy() {
        // setup
        optIn()
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
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.USER_ID))
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.PROFILE))
    }
    
    func testReset_And_ClearIdentifiers_CalledOnOptOut() {
        // setup
        optIn()
        audienceState.setAamServer(server: AudienceStateTests.aamServer)
        audienceState.setAamTimeout(timeout: AudienceStateTests.aamTimeout)
        audienceState.setDpid(dpid: AudienceStateTests.inMemoryDpid)
        audienceState.setDpuuid(dpuuid: AudienceStateTests.inMemoryDpuuid)
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        audienceState.setVisitorProfile(visitorProfile: AudienceStateTests.inMemoryVisitorProfile)
        
        // test
        optOut(shouldSendOptOutHit: true) // optout hit should be sent
        
        // verify
        XCTAssertTrue(audienceState.getAamServer().isEmpty)
        XCTAssertEqual(AudienceConstants.Default.TIMEOUT, audienceState.getAamTimeout())
        XCTAssertTrue(audienceState.getDpid().isEmpty)
        XCTAssertTrue(audienceState.getDpuuid().isEmpty)
        XCTAssertTrue(audienceState.getUuid().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.USER_ID))
        XCTAssertTrue(audienceState.getVisitorProfile().isEmpty)
        XCTAssertFalse(dataStore.contains(key: AudienceConstants.DataStoreKeys.PROFILE))
    }
    
    func testSendOptOutHit_NotCalledOnOptOut_MissingAAMServer() {
        // setup
        optIn()
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // test
        optOut(shouldSendOptOutHit: false) // optout hit should be sent
        
        // verify
        XCTAssertTrue(audienceState.getUuid().isEmpty)
    }
    
    func testSendOptOutHit_NotCalledOnOptOut_MissingUUID() {
        // setup
        optIn()
        audienceState.setAamServer(server: AudienceStateTests.aamServer)
        
        // test
        optOut(shouldSendOptOutHit: false) // optout hit should be sent
        
        // verify
        XCTAssertTrue(audienceState.getAamServer().isEmpty)
    }
    
    func testSendOptOutHit_CalledOnOptOut() {
        // setup
        optIn()
        audienceState.setAamServer(server: AudienceStateTests.aamServer)
        audienceState.setUuid(uuid: AudienceStateTests.inMemoryUuid)
        
        // test
        optOut(shouldSendOptOutHit: true) // optout hit should be sent
        
        // verify
        XCTAssertTrue(audienceState.getAamServer().isEmpty)
        XCTAssertTrue(audienceState.getUuid().isEmpty)
    }
    
    func testGetStateData_Happy() {
        // setup
        optIn()
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
        optOut()
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
    
    // ==========================================================================
    // handleHitResponse
    // ==========================================================================
    func testHandleHitResponseHappy() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        var profileInDispatchResponse:[String: String] = [:]
        var eventInDispatchResponse:Event?
        var eventInCreateSharedState:Event?
        var audienceSharedState:[String: Any] = [:]
        let hit = AudienceHit.fakeHit()
        let hitResponse = AudienceHitResponse.fakeHitResponse()
        // setup configuration settings in audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: AudienceStateTests.configEvent, configSharedState: AudienceStateTests.configSharedState, createSharedState: { data, event in
        }, dispatchOptOutResult: { (optedOut, event) in})
        
        // test
        audienceState.handleHitResponse(hit: hit, responseData: try! JSONEncoder().encode(hitResponse), dispatchResponse: { visitorProfile, event in
            profileInDispatchResponse = visitorProfile
            eventInDispatchResponse = event
            semaphore.signal()
        }, createSharedState: { createdState, event in
            audienceSharedState = createdState
            eventInCreateSharedState = event
            semaphore2.signal()
        })
        semaphore.wait()
        semaphore2.wait()

        // verify
        XCTAssertEqual(AudienceStateTests.expectedVisitorProfile, profileInDispatchResponse) // the stuff array in the hit response should be in the dispatched response event
        XCTAssertNotNil(eventInDispatchResponse)
        XCTAssertEqual(eventInDispatchResponse?.type, EventType.audienceManager)
        XCTAssertEqual(eventInDispatchResponse?.source, EventSource.requestIdentity)
        XCTAssertEqual(AudienceStateTests.expectedVisitorProfile, audienceSharedState[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String : String] ?? [:]) // the stuff array in the hit response should be updated in the audience shared state
        XCTAssertEqual("fakeUuid", audienceSharedState[AudienceConstants.EventDataKeys.UUID] as? String ?? "") // the uuid in the response should be updated in the audience shared state
        XCTAssertNotNil(eventInCreateSharedState)
        XCTAssertEqual(eventInCreateSharedState?.type, EventType.audienceManager)
        XCTAssertEqual(eventInCreateSharedState?.source, EventSource.requestIdentity)
    }
    
    func testHandleHitResponseWithEmptyConfigurationSettingsInAudienceState() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        let semaphore2 = DispatchSemaphore(value: 0)
        var profileInDispatchResponse:[String: String] = [:]
        var eventInDispatchResponse:Event?
        var eventInCreateSharedState:Event?
        var audienceSharedState:[String: Any] = [:]
        let hit = AudienceHit.fakeHit()
        let hitResponse = AudienceHitResponse.fakeHitResponse()
        // setup empty configuration settings in audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: AudienceStateTests.configEvent, configSharedState: [:], createSharedState: { data, event in
        }, dispatchOptOutResult: { (optedOut, event) in})
        
        // test
        audienceState.handleHitResponse(hit: hit, responseData: try! JSONEncoder().encode(hitResponse), dispatchResponse: { visitorProfile, event in
            profileInDispatchResponse = visitorProfile
            eventInDispatchResponse = event
            semaphore.signal()
        }, createSharedState: { createdState, event in
            audienceSharedState = createdState
            eventInCreateSharedState = event
            semaphore2.signal()
        })
        semaphore.wait()
        semaphore2.wait()

        // verify
        XCTAssertEqual([:], profileInDispatchResponse) // an empty profile should be dispatched
        XCTAssertEqual(eventInDispatchResponse?.type, EventType.audienceManager)
        XCTAssertEqual(eventInDispatchResponse?.source, EventSource.requestIdentity)
        XCTAssertEqual([:], audienceSharedState[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String : String] ?? [:]) // no visitor profile should be updated in the audience shared state
        XCTAssertEqual("", audienceSharedState[AudienceConstants.EventDataKeys.UUID] as? String ?? "") // no uuid should be updated in the audience shared state
        XCTAssertNotNil(eventInCreateSharedState)
        XCTAssertEqual(eventInCreateSharedState?.type, EventType.audienceManager)
        XCTAssertEqual(eventInCreateSharedState?.source, EventSource.requestIdentity)
    }

}

// MARK: fake hit and fake response for testing
private extension AudienceHit {
    static func fakeHit() -> AudienceHit {
        let event = Event(name: "Hit Event", type: EventType.audienceManager, source: EventSource.requestIdentity, data: nil)
        let hit = AudienceHit(url: URL(string: "adobe.com")!, timeout: AudienceConstants.Default.TIMEOUT, event: event)

        return hit
    }
}

private extension AudienceHitResponse {
    static func fakeHitResponse() -> AudienceHitResponse {
        var audienceStuffArray = [AudienceStuffObject].init()
        audienceStuffArray.append(AudienceStuffObject(cookieKey: "cookie1", cookieValue: "cookieValue1", ttl: 30, domain: "testServer.com"))
        audienceStuffArray.append(AudienceStuffObject(cookieKey: "cookie2", cookieValue: "cookieValue2", ttl: 30, domain: "testServer.com"))
        let destsArray = [["c":"www.adobe.com"],["c":"www.google.com"]]
        return AudienceHitResponse(uuid: "fakeUuid", stuff: audienceStuffArray, dests: destsArray, region: 9, tid: "fakeTid")
    }
}

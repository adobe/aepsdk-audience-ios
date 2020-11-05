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
@testable import AEPCore
@testable import AEPServices
import AEPAudience
import AEPIdentity
import AEPLifecycle

class AudienceManagerFunctionalTests: XCTestCase {
    // config constants
    static let EXPERIENCE_CLOUD_ORGID = "experienceCloud.org"
    static let GLOBAL_CONFIG_PRIVACY = "global.privacy"
    static let AAM_SERVER = "audience.server"
    static let AAM_TIMEOUT = "audience.timeout"
    static let ANALYTICS_AAM_FORWARDING = "analytics.aamForwardingEnabled"

    override func setUp() {
        UserDefaults.clear()
        ServiceProvider.shared.reset()
        EventHub.reset()
    }

    override func tearDown() {
        let unregisterExpectation = XCTestExpectation(description: "unregister extensions")
        unregisterExpectation.expectedFulfillmentCount = 2
        MobileCore.unregisterExtension(Audience.self) {
            unregisterExpectation.fulfill()
        }

        MobileCore.unregisterExtension(Identity.self) {
            unregisterExpectation.fulfill()
        }
        
        wait(for: [unregisterExpectation], timeout: 2)
    }

    func initExtensionsAndWait() {
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Audience.self, Lifecycle.self, Identity.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 1)
    }
    
    func setupConfiguration(privacyStatus: String, aamForwardingStatus: Bool) {
        MobileCore.updateConfigurationWith(configDict: [AudienceManagerFunctionalTests.GLOBAL_CONFIG_PRIVACY: privacyStatus, AudienceManagerFunctionalTests.AAM_SERVER: "testServer.com", AudienceManagerFunctionalTests.AAM_TIMEOUT: 10, AudienceManagerFunctionalTests.ANALYTICS_AAM_FORWARDING: aamForwardingStatus, AudienceManagerFunctionalTests.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", "experienceCloud.server": "identityTestServer.com"])
        sleep(1)
    }
    
//    func mockAudienceResponse(expectedUrlFragment: String, url: String, statusCode: Int) {
//        let initExpectation = XCTestExpectation(description: "get audience response")
//
//        let response = HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: [:])
//
//        mockNetworkService.mock { request in
//            initExpectation.fulfill()
//            XCTAssertTrue(request.url.absoluteString.contains(expectedUrlFragment))
//            return (data: nil, response: response, error: nil)
//        }
//        wait(for: [initExpectation], timeout: 2)
//    }
    
    // MARK: signalWithData(...) tests
    func testSignalWithData_Smoke() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optedin", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        
        // test
        let traits = ["trait": "b"] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual([:], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        if let request = mockNetworkService.getRequest(at: 0) {
            XCTAssertTrue(request.url.absoluteString.contains("https://testServer.com/event?"))
            XCTAssertTrue(request.url.absoluteString.contains("d_mid="))
            XCTAssertTrue(request.url.absoluteString.contains("c_trait=b"))
            XCTAssertTrue(request.url.absoluteString.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
        } else {
            XCTFail()
        }
    }
    
    func testSignalWithData_SignalAfterReset() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optedin", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        
        // test
        Audience.reset()
        let traits = ["trait": "b"] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual([:], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        if let request = mockNetworkService.getRequest(at: 0) {
            XCTAssertTrue(request.url.absoluteString.contains("https://testServer.com/event?"))
            XCTAssertTrue(request.url.absoluteString.contains("d_mid="))
            XCTAssertTrue(request.url.absoluteString.contains("c_trait=b"))
            XCTAssertTrue(request.url.absoluteString.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
        } else {
            XCTFail()
        }
    }
    
//    func testSignalWithDataEvent_IdentityDataInAudienceState() {
//        // setup
//        // create configuration shared state and process it with the Audience State
//        addConfigurationSettingsToAudienceState(privacyStatus: PrivacyStatus.optedIn)
//        // create identity shared state and process it with the Audience State
//        addIdentityVariablesToAudienceState()
//        // create the signalWithData event
//        let eventData = ["trait": "b"] as [String: Any]
//        let event = Event(name: "AudienceRequestContent", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
//
//        // test
//        mockRuntime.simulateComingEvent(event: event)
//
//        // verify
//        XCTAssertEqual(1, audience.state?.hitQueue.count())
//        let audienceHit = convertToAudienceHit(audienceDataEntity: mockHitQueue.getQueuedHits()[0])
//        XCTAssertEqual("https://testServer.com/event?c_trait=b&d_mid=1234567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%011&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json", audienceHit?.url.absoluteString)
//    }
//
//    func testSignalWithDataEvent_IdentityDataInAudienceState_PrivacyOptedOut() {
//        // setup
//        // create configuration shared state and process it with the Audience State
//        addConfigurationSettingsToAudienceState(privacyStatus: PrivacyStatus.optedOut)
//        // create identity shared state and process it with the Audience State
//        addIdentityVariablesToAudienceState()
//        // create the signalWithData event
//        let eventData = ["trait": "b"] as [String: Any]
//        let event = Event(name: "AudienceRequestContent", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
//
//        // test
//        mockRuntime.simulateComingEvent(event: event)
//
//        // verify no hit is queued because privacy is opted out
//        XCTAssertEqual(0, audience.state?.hitQueue.count())
//    }
//
//    func testSignalWithDataEvent_IdentityDataInAudienceState_PrivacyUnknown() {
//        // setup
//        // create configuration shared state and process it with the Audience State
//        addConfigurationSettingsToAudienceState(privacyStatus: PrivacyStatus.unknown)
//        // create identity shared state and process it with the Audience State
//        addIdentityVariablesToAudienceState()
//        // create the signalWithData event
//        let eventData = ["trait": "b"] as [String: Any]
//        let event = Event(name: "AudienceRequestContent", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
//
//        // test
//        mockRuntime.simulateComingEvent(event: event)
//
//        // verify hit is queued because privacy is unknown
//        XCTAssertEqual(1, audience.state?.hitQueue.count())
//        let audienceHit = convertToAudienceHit(audienceDataEntity: mockHitQueue.getQueuedHits()[0])
//        XCTAssertEqual("https://testServer.com/event?c_trait=b&d_mid=1234567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%011&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json", audienceHit?.url.absoluteString)
//    }
//
//    // MARK: getVisitorProfile(...) tests
//    /// Tests that a getVisitorProfile event retrieves a [String: String] dictionary containing any visitor profiles present in the Audience State
//    func testGetVisitorProfileEvent_VisitorProfileInAudienceState() {
//        // setup
//        let inMemoryVisitorProfile = ["visitorTrait":"visitorTraitValue", "anotherVisitorTrait":"anotherVisitorTraitValue"]
//        // add visitor profiles to the Audience State
//        audience?.state?.setVisitorProfile(visitorProfile: inMemoryVisitorProfile)
//        // create the getVisitorProfileEvent
//        let event = Event(name: "AudienceRequestIdentity", type: EventType.audienceManager, source: EventSource.requestIdentity, data: nil)
//
//        // test
//        mockRuntime.simulateComingEvent(event: event)
//
//        // verify
//        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
//        let dispatchedEvent = mockRuntime.dispatchedEvents.first
//        XCTAssertEqual(inMemoryVisitorProfile, dispatchedEvent?.data?[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String : String])
//    }
//
//    /// Tests that a getVisitorProfile event retrieves a [String: String] dictionary containing any visitor profiles present in the datastore if the Audience State does not contain any visitor profiles
//    func testGetVisitorProfileEvent_VisitorProfileInAudienceStateAndInDataStore() {
//        // setup
//        let inMemoryVisitorProfile = [String: String]()
//        let persistedVisitorProfile = ["persistedVisitorTrait":"persistedVisitorTraitValue", "anotherPersistedVisitorTrait":"anotherPersistedVisitorTraitValue"]
//        // add empty visitor profiles to the Audience State
//        audience?.state?.setVisitorProfile(visitorProfile: inMemoryVisitorProfile)
//        // add visitor profiles to the data store
//        dataStore.set(key: AudienceConstants.DataStoreKeys.PROFILE_KEY, value: persistedVisitorProfile)
//        // create the getVisitorProfileEvent
//        let event = Event(name: "AudienceRequestIdentity", type: EventType.audienceManager, source: EventSource.requestIdentity, data: nil)
//
//        // test
//        mockRuntime.simulateComingEvent(event: event)
//
//        // verify
//        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)
//        let dispatchedEvent = mockRuntime.dispatchedEvents.first
//        XCTAssertEqual(persistedVisitorProfile, dispatchedEvent?.data?[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String : String])
//    }
//
//    // MARK: reset(...) tests
//    func testReset_VerifyDataInAudienceStateIsCleared() {
//        // setup
//        audience?.state?.setDpid(dpid: "testDpid")
//        audience?.state?.setDpuuid(dpuuid: "testDpuuid")
//        audience?.state?.setUuid(uuid: "testUuid")
//        audience?.state?.setVisitorProfile(visitorProfile: ["key1":"value1","key2":"value2","key3":"value3"])
//        // create configuration shared state and process it with the Audience State
//        addConfigurationSettingsToAudienceState(privacyStatus: PrivacyStatus.optedIn)
//        // create identity shared state and process it with the Audience State
//        addIdentityVariablesToAudienceState()
//        // create the reset event
//        let event = Event(name: "AudienceRequestReset", type: EventType.audienceManager, source: EventSource.requestReset, data: nil)
//
//        // verify data was set
//        XCTAssertEqual(PrivacyStatus.optedIn, audience?.state?.getPrivacyStatus())
//        XCTAssertEqual("testDpid", audience?.state?.getDpid())
//        XCTAssertEqual("testDpuuid", audience?.state?.getDpuuid())
//        XCTAssertEqual("testUuid", audience?.state?.getUuid())
//        XCTAssertEqual(["key1":"value1","key2":"value2","key3":"value3"], audience?.state?.getVisitorProfile())
//        XCTAssertEqual(false, audience?.state?.getAamForwardingStatus())
//        XCTAssertEqual("testServer.com", audience?.state?.getAamServer())
//        XCTAssertEqual("testOrg@AdobeOrg", audience?.state?.getOrgId())
//        XCTAssertEqual("1234567", audience?.state?.getEcid())
//        XCTAssertEqual("blobValue", audience?.state?.getBlob())
//        XCTAssertEqual("9", audience?.state?.getLocationHint())
//        XCTAssertEqual(AudienceManagerFunctionalTests.customIds, audience?.state?.getVisitorIds())
//
//        // test
//        mockRuntime.simulateComingEvent(event: event)
//
//        // verify the audience state has been cleared
//        XCTAssertEqual(PrivacyStatus.optedIn, audience?.state?.getPrivacyStatus())
//        XCTAssertEqual("", audience?.state?.getDpid())
//        XCTAssertEqual("", audience?.state?.getDpuuid())
//        XCTAssertEqual("", audience?.state?.getUuid())
//        XCTAssertEqual([:], audience?.state?.getVisitorProfile())
//        XCTAssertEqual(false, audience?.state?.getAamForwardingStatus())
//        XCTAssertEqual("", audience?.state?.getAamServer())
//        XCTAssertEqual(2.0, audience?.state?.getAamTimeout()) // the default aam timeout should be returned
//        XCTAssertEqual("", audience?.state?.getOrgId())
//        XCTAssertEqual("", audience?.state?.getEcid())
//        XCTAssertEqual("", audience?.state?.getBlob())
//        XCTAssertEqual("", audience?.state?.getLocationHint())
//        XCTAssertEqual([], audience?.state?.getVisitorIds())
//    }
}

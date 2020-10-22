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

class AudienceTests: XCTestCase {
    var audience: Audience!
    var mockRuntime: TestableExtensionRuntime!
    let dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        MobileCore.setLogLevel(level: .error) // reset log level to error before each test
        mockRuntime = TestableExtensionRuntime()
        audience = Audience(runtime: mockRuntime)
        audience.onRegistered()
    }

    override func tearDown() {
        // clean the datastore after each test
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Tests that when audience receives a audience reset event
    func testAudienceResetHappy() {
    }

    // ========================================================================================================
    // handleConfigurationResponse
    // ========================================================================================================
    func testHandleConfigurationResponse_PrivacyStatusOptedIn() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create config data containing a privacy status and an aam server
        let data = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue, AudienceConstants.Configuration.AAM_SERVER: "testserver.com"] as [String: Any]
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (data, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(.optedIn, audience?.state?.getPrivacyStatus()) // audience state privacy status should have updated to opt-in
        // audience manager variables should be in memory
        XCTAssertEqual("testDpid", audience?.state?.getDpid())
        XCTAssertEqual("testUuid", audience?.state?.getUuid())
        XCTAssertEqual("testDpuuid", audience?.state?.getDpuuid())
        XCTAssertEqual(["profilekey": "profileValue"], audience?.state?.getVisitorProfile())
        // uuid and visitor profile should be persisted in the datastore
        XCTAssertEqual("testUuid", dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID_KEY, fallback: ""))
        XCTAssertEqual(["profilekey": "profileValue"], dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE_KEY, fallback: [:]) as! [String : String])
    }

    func testHandleConfigurationResponse_PrivacyStatusOptedUnknown() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create config data containing a privacy status and an aam server
        let data = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.unknown.rawValue, AudienceConstants.Configuration.AAM_SERVER: "testserver.com"] as [String: Any]
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (data, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(.unknown, audience?.state?.getPrivacyStatus()) // audience state privacy status should have updated to unknown
        // audience manager variables should be in memory
        XCTAssertEqual("testDpid", audience?.state?.getDpid())
        XCTAssertEqual("testUuid", audience?.state?.getUuid())
        XCTAssertEqual("testDpuuid", audience?.state?.getDpuuid())
        XCTAssertEqual(["profilekey": "profileValue"], audience?.state?.getVisitorProfile())
        // uuid and visitor profile should be persisted in the datastore
        XCTAssertEqual("testUuid", dataStore.getString(key: AudienceConstants.DataStoreKeys.USER_ID_KEY, fallback: ""))
        XCTAssertEqual(["profilekey": "profileValue"], dataStore.getDictionary(key: AudienceConstants.DataStoreKeys.PROFILE_KEY, fallback: [:]) as! [String : String])
    }

    func testHandleConfigurationResponse_PrivacyStatusOptedOut_When_AamServerAndUuidPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create config data containing a privacy status and an aam server
        let data = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue, AudienceConstants.Configuration.AAM_SERVER: "testserver.com"] as [String: Any]
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (data, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        XCTAssertTrue(mockNetworkService.connectAsyncCalled) // network request for opt-out hit should have been sent
        XCTAssertEqual(.optedOut, audience?.state?.getPrivacyStatus()) // audience state privacy status should have updated to opt-out
        // audience manager variables should be cleared
        XCTAssertEqual("", audience?.state?.getDpid())
        XCTAssertEqual("", audience?.state?.getUuid())
        XCTAssertEqual("", audience?.state?.getDpuuid())
        XCTAssertEqual([:], audience?.state?.getVisitorProfile())
        XCTAssertEqual("https://testserver.com/demoptout.jpg?d_uuid=testUuid", mockNetworkService.connectAsyncCalledWithNetworkRequest?.url.absoluteString)
    }

    func testHandleConfigurationResponse_PrivacyStatusOptedOut_When_UuidIsEmpty() {
        // setup
        audience.state?.setUuid(uuid: "")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create config data containing a privacy status and an aam server
        let data = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue, AudienceConstants.Configuration.AAM_SERVER: "testserver.com"] as [String: Any]
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (data, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        XCTAssertFalse(mockNetworkService.connectAsyncCalled) // network request for opt-out hit should not have been sent because no uuid is stored
        XCTAssertEqual(.optedOut, audience?.state?.getPrivacyStatus()) // audience state privacy status should have updated to opt-out
        // audience manager variables should be cleared
        XCTAssertEqual("", audience?.state?.getDpid())
        XCTAssertEqual("", audience?.state?.getUuid())
        XCTAssertEqual("", audience?.state?.getDpuuid())
        XCTAssertEqual([:], audience?.state?.getVisitorProfile())
        XCTAssertNil(mockNetworkService.connectAsyncCalledWithNetworkRequest?.url.absoluteString)
    }

    func testHandleConfigurationResponse_PrivacyStatusOptedOut_When_AamServerIsNotPresentInTheConfigurationEvent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create config data containing a privacy status only
        let data = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue] as [String: Any]
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (data, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        XCTAssertFalse(mockNetworkService.connectAsyncCalled) // network request for opt-out hit should not have been sent because no aam server is available in the config
        XCTAssertEqual(.optedOut, audience?.state?.getPrivacyStatus()) // audience state should have updated to opt-out
        // audience manager variables should be cleared
        XCTAssertEqual("", audience?.state?.getDpid())
        XCTAssertEqual("", audience?.state?.getUuid())
        XCTAssertEqual("", audience?.state?.getDpuuid())
        XCTAssertEqual([:], audience?.state?.getVisitorProfile())
        XCTAssertNil(mockNetworkService.connectAsyncCalledWithNetworkRequest?.url.absoluteString)
    }

    func testHandleConfigurationResponse_PrivacyStatusOptedOut_When_AamServerIsEmpty() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create config data containing a privacy status and an empty aam server
        let data = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue, AudienceConstants.Configuration.AAM_SERVER: ""] as [String: Any]
        // create the configuration response content event with the data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (data, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        XCTAssertFalse(mockNetworkService.connectAsyncCalled) // network request for opt-out hit should not have been sent because the aam server is empty in the config
        XCTAssertEqual(.optedOut, audience?.state?.getPrivacyStatus()) // audience state should have updated to opt-out
        // audience manager variables should be cleared
        XCTAssertEqual("", audience?.state?.getDpid())
        XCTAssertEqual("", audience?.state?.getUuid())
        XCTAssertEqual("", audience?.state?.getDpuuid())
        XCTAssertEqual([:], audience?.state?.getVisitorProfile())
        XCTAssertNil(mockNetworkService.connectAsyncCalledWithNetworkRequest?.url.absoluteString)
    }
}

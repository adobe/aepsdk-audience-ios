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
    var mockHitQueue: MockHitQueue!
    var responseCallbackArgs = [(DataEntity, Data?)]()
    let dataStore = NamedCollectionDataStore(name: AudienceConstants.DataStoreKeys.AUDIENCE_MANAGER_SHARED_PREFS_DATA_STORE)

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        MobileCore.setLogLevel(level: .error) // reset log level to error before each test
        mockRuntime = TestableExtensionRuntime()
        mockHitQueue = MockHitQueue(processor: AudienceHitProcessor(responseHandler: { [weak self] entity, data in
            self?.responseCallbackArgs.append((entity, data))
        }))
        audience = Audience(runtime: mockRuntime, hitQueue: mockHitQueue)
        audience.onRegistered()
    }

    override func tearDown() {
        // clean the datastore after each test
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    private func dispatchConfigurationEventForLifecycleTesting(aamServer: String, aamForwardingStatus: Bool, privacyStatus: PrivacyStatus) -> [String:Any]{
        // setup configuration data
        let configData = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: privacyStatus.rawValue, AudienceConstants.Configuration.AAM_SERVER: aamServer, AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING: aamForwardingStatus] as [String: Any]
        // create a configuration event with the created event data
        let configEvent = Event(name: "configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: configEvent, data: (configData, .set))
        let _ = audience.readyForEvent(configEvent)
        // dispatch the event
        mockRuntime.simulateComingEvent(event: configEvent)
        // return config data for use as shared state
        return configData
    }

    /// Tests that when audience receives a audience reset event
    func testAudienceResetHappy() {
    }

    // ==========================================================================
    // handleConfigurationResponse
    // ==========================================================================
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

    // ==========================================================================
    // handleLifecycleResponse
    // ==========================================================================
    func testHandleLifecycleResponse_ConfigurationIsValidAndPrivacyOptedIn() {
        // setup
        // dispatch a configuration response event containing privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForLifecycleTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // verify
        XCTAssertEqual(1, audience.hitQueue?.count())
    }
    
    func testHandleLifecycleResponse_ConfigurationMissingAAMServer() {
        // setup
        // dispatch a configuration response event containing privacy status opted in and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForLifecycleTesting(aamServer: "", aamForwardingStatus: false, privacyStatus: .optedIn)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // verify
        XCTAssertEqual(0, audience.hitQueue?.count())
    }
    
    func testHandleLifecycleResponse_ConfigurationHasAAMForwardingTrue() {
        // setup
        // dispatch a configuration response event containing privacy status opted in, aam server, and aam forwarding status equal to true
        let configData = dispatchConfigurationEventForLifecycleTesting(aamServer: "testServer.com", aamForwardingStatus: true, privacyStatus: .optedIn)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // verify
        XCTAssertEqual(0, audience.hitQueue?.count())
    }
    
    func testHandleLifecycleResponse_ConfigurationHasPrivacyStatusOptedOut() {
        // setup
        // dispatch a configuration response event containing privacy status opted out, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForLifecycleTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedOut)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // verify
        XCTAssertEqual(0, audience.hitQueue?.count())
    }
    
    func testHandleLifecycleResponse_LifecycleResponseHasEmptyData() {
        // setup
        // dispatch a configuration response event containing privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForLifecycleTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedOut)
        // create the lifecycle event with empty data and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // verify
        XCTAssertEqual(0, audience.hitQueue?.count())
    }
    
    func testHandleLifecycleResponse_ConfigurationSharedStateIsPending() {
        // setup
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having no configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (nil, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // verify
        XCTAssertEqual(0, audience.hitQueue?.count())
    }
    
    // ==========================================================================
    // handleAnalyticsResponse
    // ==========================================================================
    func testHandleAnalyticsResponse_WithStuffAndDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForLifecycleTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cn\":\"testCookieName\",\"cv\":\"segments=1606170,2461982\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[\"http://www.adobe.com\",\"http://www.testsite.com\"]}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)
        
        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual("segments=1606170,2461982", visitorProfile?["testCookieName"])
        XCTAssertEqual("segments=1234567,7890123", visitorProfile?["anotherCookieName"])
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("http://www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("http://www.testsite.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
    }
}

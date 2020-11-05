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

class AudienceTests: XCTestCase {
    var audience: Audience!
    var mockRuntime: TestableExtensionRuntime!
    var mockHitQueue: MockHitQueue!
    var responseCallbackArgs = [(DataEntity, Data?)]()
    let dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)
    var audienceState: AudienceState!
    static let configEvent = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        MobileCore.setLogLevel(.error) // reset log level to error before each test
        mockRuntime = TestableExtensionRuntime()
        mockHitQueue = MockHitQueue(processor: AudienceHitProcessor(responseHandler: { [weak self] entity, data in
            self?.responseCallbackArgs.append((entity, data))
        }))
        audienceState = AudienceState(hitQueue: mockHitQueue)
        audience = Audience(runtime: mockRuntime, state: audienceState)
        audience.onRegistered()
    }

    override func tearDown() {
        // clean the defaults after each test
        UserDefaults.clear()
    }

    // MARK: helpers
    private func dispatchConfigurationEventForTesting(aamServer: String?, aamForwardingStatus: Bool, privacyStatus: PrivacyStatus, aamTimeout: TimeInterval?) -> [String:Any]{
        // setup configuration data
        let configData = [AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: privacyStatus.rawValue, AudienceConstants.Configuration.AAM_SERVER: aamServer as Any, AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING: aamForwardingStatus, AudienceConstants.Configuration.AAM_TIMEOUT: aamTimeout as Any] as [String: Any]
        // create a configuration event with the created event data
        let configEvent = Event(name: "configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: configData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: configEvent, data: (configData, .set))
        let _ = audience.readyForEvent(configEvent)
        // dispatch the event
        mockRuntime.simulateComingEvent(event: configEvent)
        // return config data for use as shared state
        return configData
    }

    //MARK: Audience Unit Tests

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

    func testHandleConfigurationResponse_PrivacyStatusOptedOut_When_AamServerIsMissing() {
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

    func testHandleConfigurationResponse_When_ConfigDataIsEmpty() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setDpuuid(dpuuid: "testDpuuid")
        audience.state?.setDpid(dpid: "testDpid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // create the configuration response content event with empty data
        let event = Event(name: "Test Configuration response", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (nil, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify no config is set and default values are returned
        XCTAssertEqual(false, audience?.state?.getAamForwardingStatus())
        XCTAssertEqual("", audience?.state?.getAamServer())
        XCTAssertEqual(2.0, audience?.state?.getAamTimeout())
        XCTAssertEqual("", audience?.state?.getOrgId())
        XCTAssertEqual(PrivacyStatus.unknown, audience?.state?.getPrivacyStatus())
    }

    // ==========================================================================
    // handleLifecycleResponse
    // ==========================================================================
    func testHandleLifecycleResponse_ConfigurationIsValidAndPrivacyOptedIn() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_ConfigurationMissingAAMServer() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted in and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: nil, aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_ConfigurationHasEmptyAAMServer() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted in, empty aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_ConfigurationHasAAMForwardingTrue() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to true
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: true, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_ConfigurationHasPrivacyStatusOptedOut() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted out, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedOut, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_ConfigurationHasPrivacyStatusUnknown() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status unknown, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .unknown, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_LifecycleResponseHasNoData() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedOut, aamTimeout: 10)
        // create the lifecycle event with empty data and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleResponse_LifecycleResponseHasEmptyData() {
        // setup
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [String: Any]()
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: "Test Lifecycle response", type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
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
        XCTAssertEqual(0, audience.state?.hitQueue.count())
    }

    func testHandleLifecycleStartEvent_When_UuidIsPresentInAudienceState() {
        // set a uuid in the audience state
        audience?.state?.setUuid(uuid: "audienceStateUuid")
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: AudienceConstants.Lifecycle.LIFECYCLE_START_EVENT_NAME, type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify retrieved shared state contains the set uuid
        let audienceSharedState = mockRuntime.getLatestAudienceSharedState()
        XCTAssertEqual(audienceSharedState as! [String: String], [AudienceConstants.EventDataKeys.UUID: "audienceStateUuid"])
    }

    func testHandleLifecycleStartEvent_When_UuidIsNotPresentInAudienceStateButIsPresentInDataStore() {
        // set a uuid in the datastore
        dataStore.set(key: AudienceConstants.DataStoreKeys.USER_ID_KEY, value: "dataStoreUuid")
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: AudienceConstants.Lifecycle.LIFECYCLE_START_EVENT_NAME, type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify retrieved shared state contains the uuid retrieved from the data store
        let audienceSharedState = mockRuntime.getLatestAudienceSharedState()
        XCTAssertEqual(audienceSharedState as! [String: String], [AudienceConstants.EventDataKeys.UUID: "dataStoreUuid"])
    }

    func testHandleLifecycleStartEvent_When_UuidIsNotPresentInAudienceStateOrInDataStore() {
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create lifecycle response content
        let lifecycleContextData:[String: Any] = [AudienceConstants.Lifecycle.APP_ID: "testAppId", AudienceConstants.Lifecycle.CARRIER_NAME:"testCarrier"]
        // create the lifecycle event and simulate having the configuration data in shared state
        let lifecycleEvent = Event(name: AudienceConstants.Lifecycle.LIFECYCLE_START_EVENT_NAME, type: EventType.lifecycle, source: EventSource.responseContent, data: lifecycleContextData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: lifecycleEvent, data: (configData, .set))
        let _ = audience.readyForEvent(lifecycleEvent)

        // test
        mockRuntime.simulateComingEvent(event: lifecycleEvent)

        // verify retrieved shared state is empty
        let audienceSharedState = mockRuntime.getLatestAudienceSharedState()
        XCTAssertEqual(audienceSharedState as! [String: String], [:])
    }

    // ==========================================================================
    // handleAnalyticsResponse
    // ==========================================================================
    func testHandleAnalyticsResponse_WithStuffAndDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cn\":\"testCookieName\",\"cv\":\"segments=1606170,2461982\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"www.adobe.com\"},{\"c\":\"www.google.com\"}]}"]
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
        XCTAssertEqual("www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[1]?.connectTimeout)
    }

    func testHandleAnalyticsResponse_WithStuffAndDestsInResponse_And_NoAudienceTimeout() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing no aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: nil)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cn\":\"testCookieName\",\"cv\":\"segments=1606170,2461982\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"www.adobe.com\"},{\"c\":\"www.google.com\"}]}"]
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
        XCTAssertEqual("www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests[1]?.connectTimeout)
    }

    func testHandleAnalyticsResponse_WithStuffAndEmptyDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cn\":\"testCookieName\",\"cv\":\"segments=1606170,2461982\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[]}"]
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
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
    }

    func testHandleAnalyticsResponse_WithStuffAndNoDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cn\":\"testCookieName\",\"cv\":\"segments=1606170,2461982\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\"}"]
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
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
    }

    func testHandleAnalyticsResponse_WithEmptyResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)

        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual([:], visitorProfile)
        XCTAssertEqual(0, mockNetworkService.calledNetworkRequests.count)
    }

    func testHandleAnalyticsResponse_WithEmptyStuffAndValidDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"www.adobe.com\"},{\"c\":\"www.google.com\"}]}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)

        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual([:], visitorProfile)
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[1]?.connectTimeout)
    }

    func testHandleAnalyticsResponse_WithInvalidStuffKeyAndValidDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cv\":\"segments=1606170,2461982\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"www.adobe.com\"},{\"c\":\"www.google.com\"}]}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)

        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual(["anotherCookieName": "segments=1234567,7890123"], visitorProfile)
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[1]?.connectTimeout)
    }

    func testHandleAnalyticsResponse_WithInvalidStuffValueAndValidDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"stuff\":[{\"cn\":\"testCookieName\", \"ttl\":30,\"dmn\":\"testServer.com\"}, {\"cn\":\"anotherCookieName\",\"cv\":\"segments=1234567,7890123\", \"ttl\":30,\"dmn\":\"testServer.com\"}],\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"www.adobe.com\"},{\"c\":\"www.google.com\"}]}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)

        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual(["anotherCookieName": "segments=1234567,7890123"], visitorProfile)
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[1]?.connectTimeout)
    }

    func testHandleAnalyticsResponse_WithNoStuffArrayAndValidDestsInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"www.adobe.com\"},{\"c\":\"www.google.com\"}]}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)

        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual([:], visitorProfile)
        XCTAssertEqual(2, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("www.adobe.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[1]?.url.absoluteString)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[1]?.connectTimeout)
    }

    func testHandleAnalyticsResponse_WithOneInvalidDestinationInResponse() {
        // setup
        let mockNetworkService = ServiceProvider.shared.networkService as! MockNetworking
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create analytics response content
        let analyticsResponse:[String: Any] = [AudienceConstants.Analytics.SERVER_RESPONSE: "{\"uuid\":\"62392686667681235686319212494661564917\",\"dcs_region\":9,\"tid\":\"3jqoF+VgRH4=\",\"dests\":[{\"c\":\"\"},{\"c\":\"www.google.com\"}]}"]
        // create the analytics event
        let analyticsEvent = Event(name: "Test Analytics response", type: EventType.analytics, source: EventSource.responseContent, data: analyticsResponse)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: analyticsEvent, data: (configData, .set))
        let _ = audience.readyForEvent(analyticsEvent)

        // test
        mockRuntime.simulateComingEvent(event: analyticsEvent)

        // verify
        let visitorProfile = audience?.state?.getVisitorProfile()
        XCTAssertEqual([:], visitorProfile)
        XCTAssertEqual(1, mockNetworkService.calledNetworkRequests.count)
        XCTAssertEqual("www.google.com", mockNetworkService.calledNetworkRequests[0]?.url.absoluteString)
        XCTAssertEqual(10, mockNetworkService.calledNetworkRequests[0]?.connectTimeout)
    }

    // ==========================================================================
    // handleAudienceIdentityRequest
    // ==========================================================================
    func testHandleAudienceIdentityRequest_VisitorProfileDataPresentInAudienceState() {
        // setup
        // add visitor profile data to audience state
        audience?.state?.setVisitorProfile(visitorProfile: ["key1":"value1","key2":"value2","key3":"value3"])
        // create audience identity request event
        let audienceIdentityRequestEvent = Event(name: "Test Audience Identity Request", type: EventType.audienceManager, source: EventSource.requestIdentity, data: [String: Any]())
        let _ = audience.readyForEvent(audienceIdentityRequestEvent)

        // test
        mockRuntime.simulateComingEvent(event: audienceIdentityRequestEvent)

        // verify
        let responseEvent = mockRuntime.dispatchedEvents.first(where: { $0.responseID == audienceIdentityRequestEvent.id })
        XCTAssertNotNil(responseEvent)
        XCTAssertNotNil(responseEvent?.data?[AudienceConstants.EventDataKeys.VISITOR_PROFILE])
    }

    func testHandleAudienceIdentityRequest_VisitorProfileDataNotPresentInAudienceState() {
        // setup
        // add empty visitor profile data to audience state
        audience?.state?.setVisitorProfile(visitorProfile: [:])
        // create audience identity request event
        let audienceIdentityRequestEvent = Event(name: "Test Audience Identity Request", type: EventType.audienceManager, source: EventSource.requestIdentity, data: [String: Any]())
        let _ = audience.readyForEvent(audienceIdentityRequestEvent)

        // test
        mockRuntime.simulateComingEvent(event: audienceIdentityRequestEvent)

        // verify
        let responseEvent = mockRuntime.dispatchedEvents.first(where: { $0.responseID == audienceIdentityRequestEvent.id })
        XCTAssertNotNil(responseEvent)
        XCTAssertEqual([:], responseEvent?.data?[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String: String])
    }

    // ==========================================================================
    // handleAudienceResetRequest
    // ==========================================================================
    func testHandleAudienceResetRequest_AudienceManagerIdentifiersClearedFromAudienceState() {
        // setup
        audience?.state?.setDpid(dpid: "testDpid")
        audience?.state?.setDpuuid(dpuuid: "testDpuuid")
        audience?.state?.setUuid(uuid: "testUuid")
        audience?.state?.setVisitorProfile(visitorProfile: ["key1":"value1","key2":"value2","key3":"value3"])
        // add config and identity data to the Audience State
        let customIds = [CustomIdentity(origin: "d_cid_ic", type: "DSID_20915", identifier: "test_ad_id", authenticationState: .authenticated)]
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer", AudienceConstants.Configuration.ANALYTICS_AAM_FORWARDING: false, AudienceConstants.Configuration.AAM_TIMEOUT: 10.0, AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrgId", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue] as [String: Any]
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "1234567", AudienceConstants.Identity.VISITOR_ID_BLOB: "testBlob", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String: Any]
        audience?.state?.handleConfigurationSharedStateUpdate(event: AudienceTests.configEvent, configSharedState: configSharedState, createSharedState: { data, event in
        })
        audience?.state?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)

        // verify data was set
        XCTAssertEqual(PrivacyStatus.optedIn, audience?.state?.getPrivacyStatus())
        XCTAssertEqual("testDpid", audience?.state?.getDpid())
        XCTAssertEqual("testDpuuid", audience?.state?.getDpuuid())
        XCTAssertEqual("testUuid", audience?.state?.getUuid())
        XCTAssertEqual(["key1":"value1","key2":"value2","key3":"value3"], audience?.state?.getVisitorProfile())
        XCTAssertEqual(false, audience?.state?.getAamForwardingStatus())
        XCTAssertEqual("testServer", audience?.state?.getAamServer())
        XCTAssertEqual(10.0, audience?.state?.getAamTimeout())
        XCTAssertEqual("testOrgId", audience?.state?.getOrgId())
        XCTAssertEqual("1234567", audience?.state?.getEcid())
        XCTAssertEqual("testBlob", audience?.state?.getBlob())
        XCTAssertEqual("9", audience?.state?.getLocationHint())
        XCTAssertEqual(customIds, audience?.state?.getVisitorIds())

        // create audience identity reset event
        let audienceIdentityResetRequestEvent = Event(name: "Test Audience Reset Request", type: EventType.audienceManager, source: EventSource.requestReset, data: [String: Any]())
        let _ = audience.readyForEvent(audienceIdentityResetRequestEvent)

        // test
        mockRuntime.simulateComingEvent(event: audienceIdentityResetRequestEvent)

        // verify audience state was reset but privacy status is unchanged
        XCTAssertEqual(PrivacyStatus.optedIn, audience?.state?.getPrivacyStatus())
        XCTAssertEqual("", audience?.state?.getDpid())
        XCTAssertEqual("", audience?.state?.getDpuuid())
        XCTAssertEqual("", audience?.state?.getUuid())
        XCTAssertEqual([:], audience?.state?.getVisitorProfile())
        XCTAssertEqual(false, audience?.state?.getAamForwardingStatus())
        // configuration and identity data should not be cleared if privacy is not opted out
        XCTAssertEqual("testServer", audience?.state?.getAamServer())
        XCTAssertEqual(10.0, audience?.state?.getAamTimeout()) // the default aam timeout should be returned
        XCTAssertEqual("testOrgId", audience?.state?.getOrgId())
        XCTAssertEqual("1234567", audience?.state?.getEcid())
        XCTAssertEqual("testBlob", audience?.state?.getBlob())
        XCTAssertEqual("9", audience?.state?.getLocationHint())
        XCTAssertEqual(customIds, audience?.state?.getVisitorIds())
    }

    // ==========================================================================
    // handleAudienceContentRequest
    // ==========================================================================
    func testHandleAudienceContentRequest_PrivacyStatusOptedIn_When_AamServerAndUuidPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
        // verify signaled trait is stored in audience state
        XCTAssertEqual(["trait":"traitValue"], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusOptedIn_When_AamServerEmptyAndUuidPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status opted in, empty aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
        // verify signaled trait is stored in audience state
        XCTAssertEqual(["trait":"traitValue"], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusOptedIn_When_AamServerNilAndUuidPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status opted in, no aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: nil, aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
        // verify signaled trait is stored in audience state
        XCTAssertEqual(["trait":"traitValue"], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusOptedIn_When_AamServerPresentAndUuidEmpty() {
        // setup
        audience.state?.setUuid(uuid: "")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
        // verify signaled trait is stored in audience state
        XCTAssertEqual(["trait":"traitValue"], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusUnknown_When_AamServerAndUuidPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status unknown, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .unknown, aamTimeout: 10)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
        // verify signaled trait is stored in audience state
        XCTAssertEqual(["trait":"traitValue"], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusOptedOut_When_AamServerAndUuidPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status optedout, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedOut, aamTimeout: 10)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(0, audience.state?.hitQueue.count())
        // verify signaled trait is not stored in audience state due to privacy opt out
        XCTAssertEqual([:], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusOptedIn_When_TimeoutNotPresent() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: nil)
        // create the audience content request event with signal data
        let traits = ["trait":"traitValue"]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
        // verify signaled trait is stored in audience state
        XCTAssertEqual(["trait":"traitValue"], audience?.state?.getCustomerEventData())
    }

    func testHandleAudienceContentRequest_PrivacyStatusOptedIn_When_ProvidedTraitsAreEmpty() {
        // setup
        audience.state?.setUuid(uuid: "testUuid")
        audience.state?.setVisitorProfile(visitorProfile: ["profilekey": "profileValue"])
        // dispatch a configuration response event containing aam timeout, privacy status opted in, aam server, and aam forwarding status equal to false
        let configData = dispatchConfigurationEventForTesting(aamServer: "testServer.com", aamForwardingStatus: false, privacyStatus: .optedIn, aamTimeout: 10)
        // create the audience content request event with nil traits
        let traits:[String: String] = [:]
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = traits
        let event = Event(name: "Test Audience Content request", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)
        mockRuntime.simulateSharedState(extensionName: AudienceConstants.SharedStateKeys.CONFIGURATION, event: event, data: (configData, .set))
        let _ = audience.readyForEvent(event)

        // test
        mockRuntime.simulateComingEvent(event: event)

        // verify
        XCTAssertEqual(1, audience.state?.hitQueue.count())
        // verify no signaled trait is stored in audience state
        XCTAssertEqual([:], audience?.state?.getCustomerEventData())
    }

}

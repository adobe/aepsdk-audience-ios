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

@testable import AEPCore
@testable import AEPServices
@testable import AEPAudience
import XCTest

class URL_AudienceTests: XCTestCase {
    var audienceState: AudienceState!
    var mockHitQueue: MockHitQueue!
    var responseCallbackArgs = [(DataEntity, Data?)]()

    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()

        MobileCore.setLogLevel(.error) // reset log level to error before each test
        UserDefaults.clear()
        mockHitQueue = MockHitQueue(processor: AudienceHitProcessor(responseHandler: { [weak self] entity, data in
            self?.responseCallbackArgs.append((entity, data))
        }))

        let dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)
        audienceState = AudienceState(hitQueue: mockHitQueue, dataStore: dataStore)
    }

    func testAudienceHitWithNoCustomerEventDataAndNoIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // process the created shared state and event in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { _, _ in
        }, dispatchOptOutResult: { (_, _) in})
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState, data: [:])

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    func testAudienceHitWithCustomerEventDataAndIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?c_test=data&d_mid=12345567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%011&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // create a fake synced id for use in the created identity shared state
        var customIds = [[String: Any]]()
        customIds.append(["id_origin": "d_cid_ic", "id_type": "DSID_20915", "id": "test_ad_id", "authentication_state": 1])
        // create identity shared state
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String: Any]
        // process the created shared states in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { _, _ in
        }, dispatchOptOutResult: { (_, _) in})
        audienceState?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState, data: ["test": "data"])

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    // Test Missing Identity visitor ID, no identity data should be built to the url
    func testAudienceHitWithIdentityMissingIdTypeDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%011&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // create a fake synced id for use in the created identity shared state
        var customIds = [[String: Any]]()
        customIds.append(["id_origin": "d_cid_ic", "id_type": "DSID_20915", "authentication_state": 1])
        // create identity shared state
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String: Any]
        // process the created shared states in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { _, _ in
        }, dispatchOptOutResult: { (_, _) in})
        audienceState?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState, data: [:])

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    // Test Missing Identity id type, no identity data should be built to the url
    func testAudienceHitWithIdentityMissingVisitorIdDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // create a fake synced id for use in the created identity shared state
        var customIds = [[String: Any]]()
        customIds.append(["id_origin": "d_cid_ic", "id": "test_ad_id", "authentication_state": 1])
        // create identity shared state
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String: Any]
        // process the created shared states in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { _, _ in
        }, dispatchOptOutResult: { (_, _) in})
        audienceState?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState, data: [:])

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    // Test Missing Identity authentication, no identity authentication state data, should build the url with authentication state set to 0.
    func testAudienceHitWithIdentityMissingAuthenticationDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%010&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // create a fake synced id for use in the created identity shared state
        var customIds = [[String: Any]]()
        customIds.append(["id_origin": "d_cid_ic", "id_type": "DSID_20915", "id": "test_ad_id"])
        // create identity shared state
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String: Any]
        // process the created shared states in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { _, _ in
        }, dispatchOptOutResult: { (_, _) in})
        audienceState?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState, data: [:])

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    // Test all indentity data all blank, should build the url without identity visitor id and id type.
    func testAudienceHitWithIdentityDataAllBlankValueInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // create a fake synced id for use in the created identity shared state
        var customIds = [[String: Any]]()
        customIds.append(["id_origin": "", "id_type": "", "id": "", "authentication_state": 0])
        // create identity shared state
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String: Any]
        // process the created shared states in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { _, _ in
        }, dispatchOptOutResult: { (_, _) in})
        audienceState?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState, data: [:])

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }
}

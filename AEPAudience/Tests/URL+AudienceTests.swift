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
@testable import AEPIdentity
import XCTest

class URL_AudienceTests: XCTestCase {
    var audienceState: AudienceState!
    var mockHitQueue: MockHitQueue!
    var responseCallbackArgs = [(DataEntity, Data?)]()

    override func setUp() {
        MobileCore.setLogLevel(.error) // reset log level to error before each test
        UserDefaults.clear()
        mockHitQueue = MockHitQueue(processor: AudienceHitProcessor(responseHandler: { [weak self] entity, data in
            self?.responseCallbackArgs.append((entity, data))
        }))
        audienceState = AudienceState(hitQueue: mockHitQueue)
    }

    func testAudienceHitWithNoCustomerEventDataAndNoIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // process the created shared state and event in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { data, event in
        })
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState)

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    func testAudienceHitWithWithNoCustomerEventDataAndIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%011&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        // create configuration shared state and configuration response content event
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: "Configuration response event", type: EventType.configuration, source: EventSource.responseContent, data: nil)
        // create a fake synced id for use in the created identity shared state
        let customIds = [CustomIdentity(origin: "d_cid_ic", type: "DSID_20915", identifier: "test_ad_id", authenticationState: .authenticated)]
        // create identity shared state
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String : Any]
        // process the created shared states in the audience state
        audienceState?.handleConfigurationSharedStateUpdate(event: event, configSharedState: configSharedState, createSharedState: { data, event in
        })
        audienceState?.handleIdentitySharedStateUpdate(identitySharedState: identitySharedState)
        // set a uuid for testing
        audienceState?.setUuid(uuid: "testUuid")

        // test
        let url = URL.buildAudienceHitURL(state: audienceState)

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }
}

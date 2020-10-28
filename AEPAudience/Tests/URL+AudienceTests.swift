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

    func testAudienceHitWithNoCustomerEventDataAndNoIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]

        // test
        let url = URL.buildAudienceHitURL(uuid: "testUuid", configurationSharedState: configSharedState, identitySharedState: nil, customerEventData: [String: String]())

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    func testAudienceHitWithWithNoCustomerEventDataAndIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%011&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        let configSharedState = [AudienceConstants.Configuration.AAM_SERVER: "testServer.com", AudienceConstants.Configuration.EXPERIENCE_CLOUD_ORGID: "testOrg@AdobeOrg", AudienceConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let customIds = [CustomIdentity(origin: "d_cid_ic", type: "DSID_20915", identifier: "test_ad_id", authenticationState: .authenticated)]
        let identitySharedState = [AudienceConstants.Identity.VISITOR_ID_MID: "12345567", AudienceConstants.Identity.VISITOR_ID_LOCATION_HINT: "9", AudienceConstants.Identity.VISITOR_ID_BLOB: "blobValue", AudienceConstants.Identity.VISITOR_IDS_LIST: customIds] as [String : Any]

        // test
        let url = URL.buildAudienceHitURL(uuid: "testUuid", configurationSharedState: configSharedState, identitySharedState: identitySharedState, customerEventData: [String: String]())

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }
}

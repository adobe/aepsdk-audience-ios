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

    // MARK: helpers
    private func setupAudienceState(uuid: String, aamServer: String, orgId: String, privacyStatus: PrivacyStatus, ecid: String, blob: String, locationHint: String, visitorIds: [CustomIdentity]) {
        audienceState.setUuid(uuid: uuid)
        audienceState.setAamServer(server: aamServer)
        audienceState.setOrgId(orgId: orgId)
        audienceState.setMobilePrivacy(status: privacyStatus)
        audienceState.setEcid(ecid: ecid)
        audienceState.setBlob(blob: blob)
        audienceState.setLocationHint(locationHint: locationHint)
        audienceState.setVisitorIds(visitorIds: visitorIds)
    }

    func testAudienceHitWithNoCustomerEventDataAndNoIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        setupAudienceState(uuid: "testUuid", aamServer: "testServer.com", orgId: "testOrg@AdobeOrg", privacyStatus: .optedIn, ecid: "", blob: "", locationHint: "", visitorIds: [])

        // test
        let url = URL.buildAudienceHitURL(state: audienceState)

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }

    func testAudienceHitWithWithNoCustomerEventDataAndIdentityDataInSharedState() {
        // setup
        let expectedUrl = "https://testServer.com/event?d_mid=12345567&d_blob=blobValue&dcs_region=9&d_cid_ic=DSID_20915%01test_ad_id%011&d_orgid=testOrg@AdobeOrg&d_uuid=testUuid&d_ptfm=ios&d_dst=1&d_rtbd=json"
        let customIds = [CustomIdentity(origin: "d_cid_ic", type: "DSID_20915", identifier: "test_ad_id", authenticationState: .authenticated)]
        setupAudienceState(uuid: "testUuid", aamServer: "testServer.com", orgId: "testOrg@AdobeOrg", privacyStatus: .optedIn, ecid: "12345567", blob: "blobValue", locationHint: "9", visitorIds: customIds)

        // test
        let url = URL.buildAudienceHitURL(state: audienceState)

        // verify
        XCTAssertEqual(expectedUrl, url?.absoluteString)
    }
}

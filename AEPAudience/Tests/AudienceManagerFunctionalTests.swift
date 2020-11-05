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
    
    // json for testing
    static let basicResponse = """
        {
           "uuid": "19994521975870785742420741570375407533",
           "dests": [
              {
                 "c": "https://www.google.com"
              }
           ],
           "stuff": [
              {
                 "cv": "cv_testGetVisitorProfile",
                 "cn": "cn_testGetVisitorProfile"
              }
           ]
        }
        """

    override func setUp() {
        UserDefaults.clear()
        FileManager.default.clearCache()
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
    
    func setDefaultResponse(responseData: Data?, expectedUrlFragment: String, statusCode: Int, mockNetworkService: TestableNetworkService) {
        let response = HTTPURLResponse(url: URL(string: "https://adobe.com")!, statusCode: statusCode, httpVersion: nil, headerFields: [:])

        mockNetworkService.mock { request in
            return (data: responseData, response: response, error: nil)
        }
    }
    
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
        XCTAssertEqual(1, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        XCTAssertTrue(requestUrl.contains("https://testServer.com/event?"))
        XCTAssertTrue(requestUrl.contains("d_mid="))
        XCTAssertTrue(requestUrl.contains("c_trait=b"))
        XCTAssertTrue(requestUrl.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
    }
    
    func testSignalWithData_EmptyData() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optedin", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        
        // test
        let traits = [:] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual([:], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        XCTAssertEqual(1, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        XCTAssertTrue(requestUrl.contains("https://testServer.com/event?"))
        XCTAssertTrue(requestUrl.contains("d_mid="))
        XCTAssertFalse(requestUrl.contains("c_"))
        XCTAssertTrue(requestUrl.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
    }
    
    func testSignalWithData_PrivacyOptedOut() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optout", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        
        // test
        let traits = [:] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual([:], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        XCTAssertEqual(0, mockNetworkService.requests.count)
    }
    
    func testSignalWithData_MultipleTraits() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optedin", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        
        // test
        let traits = ["trait": "b", "trait2": "traitValue2", "trait3": "c"] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual([:], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        XCTAssertEqual(1, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        XCTAssertTrue(requestUrl.contains("https://testServer.com/event?"))
        XCTAssertTrue(requestUrl.contains("d_mid="))
        XCTAssertTrue(requestUrl.contains("c_trait=b"))
        XCTAssertTrue(requestUrl.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
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
        XCTAssertEqual(1, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        XCTAssertTrue(requestUrl.contains("https://testServer.com/event?"))
        XCTAssertTrue(requestUrl.contains("d_mid="))
        XCTAssertTrue(requestUrl.contains("c_trait=b"))
        XCTAssertTrue(requestUrl.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
    }
    
    // MARK: getVisitorProfile(...) tests
    func testGetVisitorProfile_Smoke() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optedin", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        let responseData = AudienceManagerFunctionalTests.basicResponse.data(using: .utf8)
        setDefaultResponse(responseData: responseData, expectedUrlFragment: "https://testServer.com/event?", statusCode: 200, mockNetworkService: mockNetworkService)
        // test
        let traits = ["trait": "b"] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual(["cn_testGetVisitorProfile": "cv_testGetVisitorProfile"], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        XCTAssertEqual(2, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        XCTAssertTrue(requestUrl.contains("https://testServer.com/event?"))
        XCTAssertTrue(requestUrl.contains("d_mid="))
        XCTAssertTrue(requestUrl.contains("c_trait=b"))
        XCTAssertTrue(requestUrl.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
        let destUrl = mockNetworkService.getRequest(at: 1)?.url.absoluteString ?? ""
        XCTAssertEqual("https://www.google.com", destUrl)
        // part 2 of test: getVisitorProfile returns the stored visitor profile
        var visitorProfile = [String: String]()
        var returnedError: AEPError?
        let semaphore2 = DispatchSemaphore(value: 0)
        // test
        Audience.getVisitorProfile { (retrievedProfile, error) in
            visitorProfile = retrievedProfile ?? [:]
            returnedError = error
            semaphore2.signal()
        }
        semaphore2.wait()
        
        // verify
        XCTAssertEqual(["cn_testGetVisitorProfile": "cv_testGetVisitorProfile"], visitorProfile)
        XCTAssertEqual(AEPError.none, returnedError)
    }
    
    func testGetVisitorProfile_AfterReset() {
        // setup
        let semaphore = DispatchSemaphore(value: 0)
        initExtensionsAndWait()
        setupConfiguration(privacyStatus: "optedin", aamForwardingStatus: false)
        let mockNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = mockNetworkService
        let responseData = AudienceManagerFunctionalTests.basicResponse.data(using: .utf8)
        setDefaultResponse(responseData: responseData, expectedUrlFragment: "https://testServer.com/event?", statusCode: 200, mockNetworkService: mockNetworkService)
        // test
        let traits = ["trait": "b"] as [String: String]
        Audience.signalWithData(data: traits) { (visitorProfile, error) in
            XCTAssertEqual(["cn_testGetVisitorProfile": "cv_testGetVisitorProfile"], visitorProfile)
            XCTAssertEqual(AEPError.none, error)
            semaphore.signal()
        }
        
        // verify
        semaphore.wait()
        XCTAssertEqual(2, mockNetworkService.requests.count)
        let requestUrl = mockNetworkService.getRequest(at: 0)?.url.absoluteString ?? ""
        XCTAssertTrue(requestUrl.contains("https://testServer.com/event?"))
        XCTAssertTrue(requestUrl.contains("d_mid="))
        XCTAssertTrue(requestUrl.contains("c_trait=b"))
        XCTAssertTrue(requestUrl.contains("&d_orgid=testOrg@AdobeOrg&d_ptfm=ios&d_dst=1&d_rtbd=json"))
        let destUrl = mockNetworkService.getRequest(at: 1)?.url.absoluteString ?? ""
        XCTAssertEqual("https://www.google.com", destUrl)
        // part 2 of test: afer invoking reset, getVisitorProfile should return an empty dictionary
        Audience.reset()
        var visitorProfile = [String: String]()
        var returnedError: AEPError?
        let semaphore2 = DispatchSemaphore(value: 0)
        // test
        Audience.getVisitorProfile { (retrievedProfile, error) in
            visitorProfile = retrievedProfile ?? [:]
            returnedError = error
            semaphore2.signal()
        }
        semaphore2.wait()
        
        // verify
        XCTAssertEqual([:], visitorProfile)
        XCTAssertEqual(AEPError.none, returnedError)
    }
}

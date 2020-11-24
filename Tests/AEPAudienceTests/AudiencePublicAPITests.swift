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

class AudiencePublicAPITests: XCTestCase {

    override func setUp() {
        EventHub.reset()
        MockExtension.reset()
        EventHub.shared.start()
        registerMockExtension(MockExtension.self)
    }

    private func registerMockExtension<T: Extension> (_ type: T.Type) {
        let semaphore = DispatchSemaphore(value: 0)
        EventHub.shared.registerExtension(type) { (_) in
            semaphore.signal()
        }

        semaphore.wait()
    }

    /// Tests that getVisitorProfile dispatches an audience request identity event
    func testGetVisitorProfile() {
        // setup
        let expectation = XCTestExpectation(description: "getVisitorProfile should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.audienceManager, source: EventSource.requestIdentity) { (_) in
            expectation.fulfill()
        }

        // test
        Audience.getVisitorProfile { (_, _) in }

        // verify
        wait(for: [expectation], timeout: 1)
    }

    /// Tests that signalWithData dispatches an audience request content event
    func testSignalWithData() {
        // setup
        let expectation = XCTestExpectation(description: "signalWithData should dispatch an event")
        expectation.assertForOverFulfill = true
        let traits = ["key": "trait", "key2": "trait2"]

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.audienceManager, source: EventSource.requestContent) { (event) in
            XCTAssertEqual(traits, event.data?[AudienceConstants.EventDataKeys.VISITOR_TRAITS] as? [String: String])
            expectation.fulfill()
        }

        // test
        Audience.signalWithData(data: traits, completion: { (_, _) in })

        // verify
        wait(for: [expectation], timeout: 1)
    }

    /// Tests that reset dispatches an audience reset event
    func testReset() {
        // setup
        let expectation = XCTestExpectation(description: "reset should dispatch an event")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.audienceManager, source: EventSource.requestReset) { (_) in
            expectation.fulfill()
        }

        // test
        Audience.reset()

        // verify
        wait(for: [expectation], timeout: 1)
    }
}

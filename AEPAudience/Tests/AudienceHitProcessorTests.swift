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
@testable import AEPAudience
@testable import AEPServices
import XCTest

class AudienceHitProcessorTests: XCTestCase {
    let DEFAULT_TIMEOUT: TimeInterval = 2000
    var hitProcessor: AudienceHitProcessor!
    var responseCallbackArgs = [(DataEntity, Data?)]()
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        hitProcessor = AudienceHitProcessor(responseHandler: { [weak self] entity, data in
            self?.responseCallbackArgs.append((entity, data))
        })
    }

    /// Tests that when a `DataEntity` with bad data is passed, that it is not retried and is removed from the queue
    func testProcessHitBadHit() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: nil) // entity data does not contain an `AudienceHit`

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should not have been invoked
        XCTAssertFalse(mockNetworkService?.connectAsyncCalled ?? true) // no network request should have been made
    }

    /// Tests that when a good hit is processed that a network request is made and the request returns 200
    func testProcessHitHappy() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL(string: "adobe.com")!
        let expectedEvent = Event(name: "Hit Event", type: EventType.audienceManager, source: EventSource.requestContent, data: ["signalKey1": "signalKey2"])
        let hit = AudienceHit(url: expectedUrl, timeout: DEFAULT_TIMEOUT, event: expectedEvent)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(responseCallbackArgs.isEmpty) // response handler should have been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that the network request fails with a recoverable error response code doesn't invoke the response handler and the hit is retried
    func testProcessHitRecoverableNetworkError() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should be retried")
        let expectedUrl = URL(string: "adobe.com")!
        let expectedEvent = Event(name: "Hit Event", type: EventType.audienceManager, source: EventSource.requestContent, data: nil)
        let hit = AudienceHit(url: expectedUrl, timeout: DEFAULT_TIMEOUT, event: expectedEvent)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl, statusCode: NetworkServiceConstants.RECOVERABLE_ERROR_CODES.first!, httpVersion: nil, headerFields: nil), error: nil)

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should have not been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that the network request fails with unrecoverable response code invokes the response handler and the hit is dropped without retrying
    func testProcessHitUnrecoverableNetworkError() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL(string: "adobe.com")!
        let expectedEvent = Event(name: "Hit Event", type: EventType.audienceManager, source: EventSource.requestContent, data: nil)
        let hit = AudienceHit(url: expectedUrl, timeout: DEFAULT_TIMEOUT, event: expectedEvent)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl, statusCode: -1, httpVersion: nil, headerFields: nil), error: nil)

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(responseCallbackArgs.isEmpty) // response handler should have been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that the network request failing with a recoverable url error doesn't invoke the response handler and the hit is retried
    func testProcessHitRecoverableUrlError() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should be retried")
        let expectedUrl = URL(string: "adobe.com")!
        let expectedEvent = Event(name: "Hit Event", type: EventType.audienceManager, source: EventSource.requestContent, data: nil)
        let hit = AudienceHit(url: expectedUrl, timeout: DEFAULT_TIMEOUT, event: expectedEvent)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: nil, error: URLError(URLError.notConnectedToInternet))

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should have not been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that the network request fails with unrecoverable url error invokes the response handler and the hit is dropped without retrying
    func testProcessHitUnrecoverableUrlError() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL(string: "adobe.com")!
        let expectedEvent = Event(name: "Hit Event", type: EventType.audienceManager, source: EventSource.requestContent, data: nil)
        let hit = AudienceHit(url: expectedUrl, timeout: DEFAULT_TIMEOUT, event: expectedEvent)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: nil, error: URLError(URLError.badURL))

        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(responseCallbackArgs.isEmpty) // response handler should have been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }
}

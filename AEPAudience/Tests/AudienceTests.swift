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
    
    override func setUp() {
        MobileCore.setLogLevel(level: .error) // reset log level to error before each test
        mockRuntime = TestableExtensionRuntime()
        audience = Audience(runtime: mockRuntime)
        audience.onRegistered()
    }

    /// Tests that when audience receives a audience reset event
    func testAudienceHappy() {
        
    }

}

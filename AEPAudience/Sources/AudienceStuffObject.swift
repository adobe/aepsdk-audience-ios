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

import Foundation

/// Struct to represent a "stuff" object contained in a Audience Manager response.
struct AudienceStuffObject: Codable {
    /// The cookie name for the stuff object
    let cookieKey: String?

    /// The cookie value for the stuff object
    let cookieValue: String?

    /// The time to live value for the stuff object
    let ttl: Int?

    /// The domain for the stuff object
    let domain: String?

    enum CodingKeys: String, CodingKey {
        case cookieKey = "cn"
        case cookieValue = "cv"
        case ttl = "ttl"
        case domain = "dmn"
    }
}

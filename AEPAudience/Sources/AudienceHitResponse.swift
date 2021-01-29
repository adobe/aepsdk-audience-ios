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

/// Struct to represent Audience Manager Extension network call json response.
struct AudienceHitResponse: Codable {
    /// UUID value as received in the audience manager network response json
    let uuid: String?

    /// Stuff array as received in the audience manager network response json
    let stuff: [AudienceStuffObject]?

    /// Dests array as received in the audience manager network response json
    let dests: [[String: String]]?

    /// DCS region hint as received in the audience manager network response json
    let region: Int?

    /// The transaction id as received in the audience manager network response json
    let tid: String?

    enum CodingKeys: String, CodingKey {
        case uuid = "uuid"
        case stuff = "stuff"
        case dests = "dests"
        case region = "dcs_region"
        case tid = "tid"
    }
}

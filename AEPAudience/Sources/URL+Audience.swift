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
import AEPServices

extension URL {

    private static let LOG_TAG = "URL+Audience"

    /// Creates a new Audience Manager hit URL
    /// - Parameters:
    ///   - aamServer: the audience manager server
    ///   - orgId: the experience cloud org id
    ///   - ecid: the experience cloud id
    ///   - audienceState: the current `AudienceState` containing the Audience Manager extension variables
    ///   - customerEventData: the customer event data present in the triggering event
    // todo: this is just a placeholder and the passed in arguments may change
    static func buildAudienceHitURL(aamServer: String, orgId: String, ecid: String, audienceState: AudienceState, customerEventData:[String:Any]) -> URL? {
        // todo: implement this for signalWithData
        return nil
    }

    /// Builds the `URL` responsible for sending an opt-out hit
    /// - Parameters:
    ///   - aamServer: the audience manager server
    ///   - uuid: the audience manager unique user id
    /// - Returns: A network request configured to send the opt-out request, nil if failed
    static func buildOptOutURL(aamServer: String, uuid: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = aamServer
        components.path = AudienceConstants.URLKeys.AUDIENCE_MANAGER_OPT_OUT_URL_PATH
        components.queryItems = [
            URLQueryItem(name: AudienceConstants.URLKeys.AUDIENCE_MANAGER_OPT_OUT_URL_AAM_UUID, value: uuid),
        ]

        guard let url = components.url else {
            Log.error(label: LOG_TAG, "Building Audience Manager opt-out hit URL failed, returning nil.")
            return nil
        }
        return url
    }
}

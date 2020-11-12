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

import AEPServices
import Foundation

extension Networking {
    /// Sends the `NetworkRequest` containing an opt-out hit
    /// - Parameters:
    ///   - aamServer: the audience manager server
    ///   - uuid: the audience manager unique user id
    func sendOptOutRequest(aamServer: String, uuid: String) {
        guard let url = URL.buildOptOutURL(aamServer: aamServer, uuid: uuid) else { return }
        Log.debug(label: "Networking+Audience:\(#function)", "Sending opt-out hit to \(url)")
        ServiceProvider.shared.networkService.connectAsync(networkRequest: NetworkRequest(url: url), completionHandler: nil) // fire and forget
    }
}

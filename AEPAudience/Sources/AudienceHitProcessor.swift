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

class AudienceHitProcessor: HitProcessing {
    private let LOG_TAG = "AudienceHitProcessor"

    let retryInterval = TimeInterval(30)
    private let responseHandler: (DataEntity, Data?) -> Void
    private var networkService: Networking {
        return ServiceProvider.shared.networkService
    }

    /// Creates a new `AudienceHitProcessor` where the `responseHandler` will be invoked after each successful processing of a hit
    /// - Parameter responseHandler: a function to be invoked with the `DataEntity` for a hit and the response data for that hit
    init(responseHandler: @escaping (DataEntity, Data?) -> Void) {
        self.responseHandler = responseHandler
    }

    // MARK: HitProcessing

    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return retryInterval
    }

    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        guard let data = entity.data, let audienceHit = try? JSONDecoder().decode(AudienceHit.self, from: data) else {
            // failed to convert data to hit, unrecoverable error, move to next hit
            completion(true)
            return
        }

        let timeout = audienceHit.timeout ?? AudienceConstants.Default.TIMEOUT
        let headers = [NetworkServiceConstants.Headers.CONTENT_TYPE: NetworkServiceConstants.HeaderValues.CONTENT_TYPE_URL_ENCODED]
        let networkRequest = NetworkRequest(url: audienceHit.url, httpMethod: .get, connectPayload: "", httpHeaders: headers, connectTimeout: timeout, readTimeout: timeout)

        networkService.connectAsync(networkRequest: networkRequest) { connection in
            self.handleNetworkResponse(entity: entity, hit: audienceHit, connection: connection, completion: completion)
        }
    }

    // MARK: Helpers

    /// Handles the network response after a hit has been sent to the server
    /// - Parameters:
    ///   - entity: the data entity responsible for the hit
    ///   - connection: the connection returned after we make the network request
    ///   - completion: a completion block to invoke after we have handled the network response with true for success and false for failure (retry)
    private func handleNetworkResponse(entity: DataEntity, hit: AudienceHit, connection: HttpConnection, completion: @escaping (Bool) -> Void) {
        if connection.responseCode == 200 {
            // hit sent successfully
            Log.debug(label: "\(LOG_TAG):\(#function)", "Audience hit request with url \(hit.url.absoluteString) sent successfully")
            responseHandler(entity, connection.data)
            completion(true)
        } else if NetworkServiceConstants.RECOVERABLE_ERROR_CODES.contains(connection.responseCode ?? -1) {
            // retry this hit later
            Log.warning(label: "\(LOG_TAG):\(#function)", "Audience request with url:(\(hit.url.absoluteString)) failed with error:(\(connection.error?.localizedDescription ?? "")) and code:(\(connection.responseCode ?? -1)). Will Retry Audience hit in \(retryInterval) seconds")
            completion(false)
        } else {

            if let urlError = connection.error as? URLError, urlError.isRecoverable {
                // retry recoverable URL errors
                Log.warning(label: "\(LOG_TAG):\(#function)", "Audience request with url:(\(hit.url.absoluteString)) failed with error:(\(urlError.localizedDescription)) and code:(\(urlError.errorCode)). Will Retry Audience hit in \(retryInterval) seconds")
                completion(false)
                return
            }

            // unrecoverable error. delete the hit from the database and continue
            Log.warning(label: "\(LOG_TAG):\(#function)", "Dropping Audience hit, request with url \(hit.url.absoluteString) failed with error \(connection.error?.localizedDescription ?? "") and unrecoverable status code \(connection.responseCode ?? -1)")
            responseHandler(entity, connection.data)
            completion(true)
        }
    }
}

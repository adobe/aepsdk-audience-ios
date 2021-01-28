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

import AEPCore
import AEPServices
import Foundation

/// Defines the public interface for the Audience extension
@objc public extension Audience {

    /// Returns the visitor profile that was most recently obtained.
    /// - Parameters:
    ///   - completion: closure  invoked with the visitor's profile as a parameter
    @objc(getVisitorProfile:)
    static func getVisitorProfile(completion: @escaping ([String: String]?, Error?) -> Void) {
        let event = Event(name: "AudienceRequestIdentity", type: EventType.audienceManager, source: EventSource.requestIdentity, data: nil)

        MobileCore.dispatch(event: event) { responseEvent in
            guard let responseEvent = responseEvent else {
                completion(nil, AEPError.callbackTimeout)
                return
            }

            let profileData = responseEvent.data?[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String: String]
            completion(profileData, .none)
        }
    }

    /// Sends Audience Manager a signal with traits and returns the matching segments for the visitor in a closure.
    /// - Parameters:
    ///   - data: Traits data for the current visitor
    ///   - completion: closure  invoked with the visitor's profile as a parameter
    @objc(signalWithData:completion:)
    static func signalWithData(data: [String: String], completion: @escaping ([String: String]?, Error?) -> Void) {
        var eventData = [String: Any]()
        eventData[AudienceConstants.EventDataKeys.VISITOR_TRAITS] = data
        let event = Event(name: "AudienceRequestContent", type: EventType.audienceManager, source: EventSource.requestContent, data: eventData)

        MobileCore.dispatch(event: event) { responseEvent in
            guard let responseEvent = responseEvent else {
                completion(nil, AEPError.callbackTimeout)
                return
            }

            let profileData = responseEvent.data?[AudienceConstants.EventDataKeys.VISITOR_PROFILE] as? [String: String]
            completion(profileData, .none)
        }
    }

    /// Resets the Audience Manager UUID and purges the current visitor profile from NSUserDefaults.
    @objc(reset)
    static func reset() {
        let event = Event(name: "AudienceRequestReset", type: EventType.audienceManager, source: EventSource.requestReset, data: nil)

        MobileCore.dispatch(event: event)
    }
}

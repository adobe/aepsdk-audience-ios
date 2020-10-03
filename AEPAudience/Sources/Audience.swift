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

/// Audience extension for the Adobe Experience Platform SDK
@objc(AEPAudience)
public class Audience: NSObject, Extension {
    public let runtime: ExtensionRuntime

    public let name = AudienceConstants.EXTENSION_NAME
    public let friendlyName = AudienceConstants.FRIENDLY_NAME
    public static let extensionVersion = AudienceConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    //private(set) var state: AudienceState?
    
    // MARK: Extension

    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()

//        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
//            Log.error(label: getLogTagWith(functionName: #function), "Failed to create Data Queue, Audience could not be initialized")
//            return
//        }
//
//        let dataStore = NamedCollectionDataStore(name: AudienceConstants.DATASTORE_NAME)
    }
    
    /// Invoked when the `EventHub` has successfully registered the Audience extension.
    public func onRegistered() {
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleSharedStateUpdate(event:))
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleResponse(event:))
        registerListener(type: EventType.analytics, source: EventSource.responseContent, listener: handleAnalyticsResponse(event:))
        
        registerListener(type: EventType.audienceManager, source: EventSource.requestContent, listener: handleAudienceRequest(event:))
        registerListener(type: EventType.audienceManager, source: EventSource.requestIdentity, listener: handleAudienceIdentityRequest(event:))
        registerListener(type: EventType.audienceManager, source: EventSource.requestReset, listener: handleAudienceResetRequest(event:))
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponse(event:))
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }
    
    // MARK: Event Listeners

    private func handleSharedStateUpdate(event: Event) {
        
    }
    
    private func handleLifecycleResponse(event: Event) {
        
    }
    
    private func handleAnalyticsResponse(event: Event) {
        
    }
    
    private func handleAudienceRequest(event: Event) {
        
    }
    
    private func handleConfigurationResponse(event: Event) {
        
    }
    
    private func handleAudienceIdentityRequest(event: Event) {
        
    }
    
    private func handleAudienceResetRequest(event: Event) {
        
    }
    
    
    /// Updates the Audience shared state versioned at `event` with `data`
    /// - Parameters:
    ///   - event: the event to version the shared state at
    ///   - data: data for the shared state
    private func updateSharedState(event: Event, data: [String: Any]) {
        let sharedStateData = data;
        Log.trace(label: getLogTagWith(functionName: #function), "Updating Audience shared state")
        createSharedState(data: sharedStateData as [String: Any], event: event)
    }
        
    func getLogTagWith(functionName: String) -> String {
        return "\(name):\(functionName)"
    }
 }

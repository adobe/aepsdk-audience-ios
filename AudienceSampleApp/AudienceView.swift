/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import UIKit
import SwiftUI
import AEPAudience
import AEPCore

struct AudienceView: View {
    let LOG_TAG = "AudienceTestApp::AudienceView"
    var body: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: 12) {
            VStack {
                Text("Audience Manager API").bold()
                Button(action: {
                    Audience.signalWithData(data: ["trait": "trait value"]) { (traits, error) in
                        print("\(LOG_TAG)::#signalWithData - returned traits: \(String(describing: traits))")
                        if error != nil {
                            print("\(LOG_TAG)::#signalWithData - error: \(String(describing: error?.localizedDescription))")
                        }
                    }
                }) {
                    Text("Signal With Data")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)
                Button(action: {
                    Audience.getVisitorProfile { (retrievedProfile, error) in
                        print("\(LOG_TAG)::#getVisitorProfile - retrieved profile: \(String(describing: retrievedProfile))")
                        if error != nil {
                            print("\(LOG_TAG)::#getVisitorProfile - Audience getVisitorProfile error: \(String(describing: error?.localizedDescription))")
                        }
                    }
                }) {
                    Text("Get Visitor Profile")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)
                Button(action: {
                    Audience.reset()
                }) {
                    Text("Reset")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)

                Button(action: {
                    var config: [String: Any] = [:]
                    config["global.privacy"] = "optedout"
                    MobileCore.updateConfigurationWith(configDict: config)
                }) {
                    Text("OptOut")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)

                Button(action: {
                    var config: [String: Any] = [:]
                    config["global.privacy"] = "optedin"
                    MobileCore.updateConfigurationWith(configDict: config)
                }) {
                    Text("OptIn")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)
            }
        }
    }
}

struct AudienceView_Previews: PreviewProvider {
    static var previews: some View {
        AudienceView()
    }
}

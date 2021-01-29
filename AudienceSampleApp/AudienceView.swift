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

struct AudienceView: View {
    var body: some View {
        VStack(alignment: HorizontalAlignment.leading, spacing: 12) {
            VStack {
                Text("Audience Manager API").bold()
                Button(action: {
                    Audience.signalWithData(data: ["trait":"trait value"]) { (traits, error) in
                        print("returned traits: \(String(describing: traits))")
                        if(error != nil) {
                            print("audience signal with data error: \(error?.localizedDescription)")
                        }
                    }
                }){
                    Text("Signal With Data")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)
                Button(action: {
                    Audience.getVisitorProfile { (retrievedProfile, error) in
                        print("retrieved profile: \(String(describing: retrievedProfile))")
                        if(error != nil) {
                            print("audience get visitor profile error: \(error?.localizedDescription)")
                        }
                    }
                }){
                    Text("Get Visitor Profile")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .font(.caption)
                }.cornerRadius(5)
                Button(action: {
                    Audience.reset()
                }){
                    Text("Reset")
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

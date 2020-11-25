// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

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

import PackageDescription

let package = Package(
    name: "AEPAudience",
    platforms: [.iOS(.v10)],
    products: [
        // default
        .library(name: "AEPAudience", targets: ["AEPAudience"]),
        // dynamic
        .library(name: "AEPAudienceDynamic", type: .dynamic, targets: ["AEPAudience"]),
        // static
        .library(name: "AEPAudienceStatic", type: .static, targets: ["AEPAudience"]),
    ],
    dependencies: [
        .package(name: "AEPCore", url: "https://github.com/adobe/aepsdk-core-ios.git", .branch("main")),
    ],
    targets: [
        .target(name: "AEPAudience",
                dependencies: ["AEPCore", .product(name: "AEPServices", package: "AEPCore"), .product(name: "AEPIdentity", package: "AEPCore")],
                path: "AEPAudience/Sources"),
        .target(name: "AEPAudienceTests",
                dependencies: ["AEPAudience", "AEPCore", .product(name: "AEPServices", package: "AEPCore"), .product(name: "AEPIdentity", package: "AEPCore")],
                path: "AEPAudience/Tests"),
    ]
)

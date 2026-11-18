#!/bin/bash

set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

# Builds a throwaway Swift 6 consumer that calls every AEPAudience completion API with plain closures from @MainActor code.
PROJECT_NAME=Swift6Consumer

rm -rf $PROJECT_NAME
mkdir -p $PROJECT_NAME/Sources/$PROJECT_NAME && cd $PROJECT_NAME

echo "// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: \"$PROJECT_NAME\",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: \"$PROJECT_NAME\", targets: [\"$PROJECT_NAME\"])
    ],
    dependencies: [
        .package(name: \"AEPAudience\", path: \"../\")
    ],
    targets: [
        .target(
            name: \"$PROJECT_NAME\",
            dependencies: [
                .product(name: \"AEPAudience\", package: \"AEPAudience\")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)
" >Package.swift

cat >Sources/$PROJECT_NAME/Swift6Consumer.swift <<'SWIFT'
import AEPAudience

@MainActor
final class Swift6Consumer {
    var lastProfile: [String: String]?
    var lastError: Error?

    func exercise() {
        Audience.signalWithData(data: ["trait": "value"]) { profile, error in
            Task { @MainActor in
                self.lastProfile = profile
                self.lastError = error
            }
        }
        Audience.getVisitorProfile { profile, error in
            Task { @MainActor in
                self.lastProfile = profile
                self.lastError = error
            }
        }
        Audience.reset()
    }
}
SWIFT

swift package update

echo '############# Build Swift 6 consumer for generic iOS device ###############'
xcodebuild build -scheme $PROJECT_NAME -destination 'generic/platform=iOS'

cd ..
rm -rf $PROJECT_NAME

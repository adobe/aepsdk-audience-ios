# Adobe Experience Platform Audience SDK

[![CocoaPods](https://img.shields.io/github/v/release/adobe/aepsdk-audience-ios?label=CocoaPods&logo=apple&logoColor=white&color=orange)](https://cocoapods.org/pods/AEPAudience) 
[![SPM](https://img.shields.io/github/v/release/adobe/aepsdk-audience-ios?label=SPM&logo=apple&logoColor=white&color=orange)](https://github.com/adobe/aepsdk-audience-ios/releases) 
[![CircleCI](https://img.shields.io/circleci/project/github/adobe/aepsdk-audience-ios/main.svg?logo=circleci&label=Build)](https://circleci.com/gh/adobe/workflows/aepsdk-audience-ios) 
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aepsdk-audience-ios/main.svg?logo=codecov&label=Coverage)](https://codecov.io/gh/adobe/aepsdk-audience-ios/branch/main)

## About this project

The AEPAudience extension represents the Audience Manager Adobe Experience Platform SDK that is required for updating audience profiles for users and retrieving user segment information from your mobile app.

## Requirements
- Xcode 15
- Swift 5.1

## Installation
These are currently the supported installation options:

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)
```ruby
# Podfile
use_frameworks!

# For app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPAudience'
    pod 'AEPCore'
    pod 'AEPIdentity'
end

# For extension development, include AEPAudience and its dependencies
target 'YOUR_TARGET_NAME' do
    pod 'AEPAudience'
    pod 'AEPCore'
    pod 'AEPServices'
    pod 'AEPIdentity'
end
```

Replace `YOUR_TARGET_NAME` and then, in the `Podfile` directory, type:

```bash
$ pod install
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

To add the AEPAudience Package to your application, from the Xcode menu select:

`File > Add Packages...`

> **Note** 
>  The menu options may vary depending on the version of Xcode being used.

Enter the URL for the AEPAudience package repository: `https://github.com/adobe/aepsdk-audience-ios.git`.

When prompted, input a specific version or a range of versions for Version rule.

Alternatively, if your project has a `Package.swift` file, you can add AEPAudience directly to your dependencies:

```
dependencies: [
    .package(url: "https://github.com/adobe/aepsdk-audience-ios.git", .upToNextMajor(from: "5.0.0"))
]
```

### Project Reference

Include `AEPAudience.xcodeproj` in the targeted Xcode project and link all necessary libraries to your app target.

### Binaries

Run `make archive` from the root directory to generate `.xcframeworks` for each module under the `build` folder. Drag and drop all `.xcframeworks` to your app target in Xcode.

## Documentation

Additional documentation for usage and SDK architecture can be found under the [Documentation](Documentation) directory.

## Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.

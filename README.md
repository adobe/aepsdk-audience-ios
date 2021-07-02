# Adobe Experience Platform Audience SDK

[![Cocoapods](https://img.shields.io/cocoapods/v/AEPAudience.svg?color=orange&label=AEPAudience&logo=apple&logoColor=white)](https://cocoapods.org/pods/AEPAudience)

[![SPM](https://img.shields.io/badge/SPM-Supported-orange.svg?logo=apple&logoColor=white)](https://swift.org/package-manager/)
[![CircleCI](https://img.shields.io/circleci/project/github/adobe/aepsdk-audience-ios/main.svg?logo=circleci)](https://circleci.com/gh/adobe/workflows/aepsdk-audience-ios)
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aepsdk-audience-ios/main.svg?logo=codecov)](https://codecov.io/gh/adobe/aepsdk-audience-ios/branch/main)

## About this project

The AEPAudience extension represents the Audience Manager Adobe Experience Platform SDK that is required for updating audience profiles for users and retrieving user segment information from your mobile app.

## Requirements
- Xcode 11.x
- Swift 5.x

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

`File > Swift Packages > Add Package Dependency...`

Enter the URL for the AEPAudience package repository: `https://github.com/adobe/aepsdk-audience-ios.git`.

When prompted, input a specific version or a range of versions for Version rule.

There are three options for selecting your dependencies as identified by the *suffix* of the library name:

- "Dynamic" - the library will be linked dynamically
- "Static" - the library will be linked statically
- *(none)* - (default) SPM will determine whether the library will be linked dynamically or statically

Alternatively, if your project has a `Package.swift` file, you can add AEPAudience directly to your dependencies:

```
dependencies: [
    .package(url: "https://github.com/adobe/aepsdk-audience-ios.git", from: "3.0.0"),
]
```

### Project Reference

Include `AEPAudience.xcodeproj` in the targeted Xcode project and link all necessary libraries to your app target.

### Binaries

Run `make archive` from the root directory to generate `.xcframeworks` for each module under the `build` folder. Drag and drop all `.xcframeworks` to your app target in Xcode.

## Documentation

Additional documentation for usage and SDK architecture can be found under the [Documentation](Documentation/README.md) directory.

## Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.

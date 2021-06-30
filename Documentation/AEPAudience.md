
- [Getting Started](#getting-started)
  * [Set up a Mobile Property](#set-up-a-mobile-property)
  * [Get the Swift Mobile Audience](#get-the-swift-mobile-audience)
  * [Initial SDK Setup](#initial-sdk-setup)
- [Audience API reference](#audience-api-reference)
  * [extensionVersion](#extensionversion)
  * [getVisitorProfile](#getvisitorprofile)
  * [signalWithData](#signalwithdata)
  * [reset](#reset)
- [Related Project](#related-project)
  * [AEP SDK Compatibility for iOS](#aep-sdk-compatibility-for-ios)

# Getting Started

This section walks through how to get up and running with the AEP Swift Audience SDK with only a few lines of code.

## Set up a Mobile Property

Set up a mobile property as outlined in the Adobe Experience Platform [docs](https://aep-sdks.gitbook.io/docs/getting-started/create-a-mobile-property)

## Get the Swift Mobile Audience

Now that a Mobile Property is created, head over to the [install instructions](https://github.com/adobe/aepsdk-audience-ios#installation) to install the SDK.

## Initial SDK Setup

**Swift**

1. Import each of the core extensions in the `AppDelegate` file:

```swift
import AEPCore
import AEPIdentity
import AEPAudience
```

2. Register the core extensions and configure the SDK with the assigned application identifier.
   To do this, add the following code to the Application Delegate's `application(_:didFinishLaunchingWithOptions:)` method:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

 // Enable debug logging
 MobileCore.setLogLevel(level: .debug)

 MobileCore.registerExtensions([Audience.self, Identity.self], {
 // Use the App id assigned to this application via Adobe Launch
 MobileCore.configureWith(appId: "appId") 
 })  
 return true
}
```

**Objective-C**

1. Import each of the core extensions in the `AppDelegate` file:

```objective-c
@import AEPCore;
@import AEPIdentity;
@import AEPAudience;
```

2. Register the core extensions and configure the SDK with the assigned application identifier.
   To do this, add the following code to the Application Delegate's 
   `application didFinishLaunchingWithOptions:` method:

```objective-c
(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions

  // Enable debug logging
  [AEPMobileCore setLogLevel: AEPLogLevelDebug];
    
  [AEPMobileCore registerExtensions:@[AEPMobileAudience.class, AEPMobileIdentity.class] completion:^{
  // Use the App id assigned to this application via Adobe Launch
  [AEPMobileCore configureWithAppId:@"appId"];
   }];
   return YES;
}
```




# Audience API reference

This section details all the APIs provided by AEPAudience, along with sample code snippets on how to properly use the APIs.

## extensionVersion

The `extensionVersion()` API returns the version of the Audience extension that is registered with the Mobile Core extension.

**Examples**

**Swift**

```swift
let version = Audience.extensionVersion
```

**Objective-C**

```objective-c
NSString *version = [AEPMobileAudience extensionVersion];
```



## getVisitorProfile

Returns the visitor profile that was most recently updated. The visitor profile is saved in the SDK's local storage for access across multiple launches of your app. If no audience signal has been sent before, when this API is called, a null value is returned.

**Syntax**

```swift
static func getVisitorProfile(completion: @escaping ([String: String]?, Error?) -> Void)
```

**Examples**

**Swift**

```swift
Audience.getVisitorProfile { (visitorProfile, error) in
   if error != nil {
    // handle the error here
   } else {
    // handle the retrieved visitorProfile here
   }
}
```

**Objective-C**

```objective-c
[AEPMobileAudience getVisitorProfile:^(NSDictionary<NSString *,NSString *> * _Nullable visitorProfile, NSError * _Nullable error) {
   if (error) {
    // handle the error here
   } else {
    // handle the returned visitorProfile dictionary here
   }
}];
```



## signalWithData

Use this method to send a signal with traits to Audience Manager and get the matching segments for the visitor in a closure. Audience manager sends the UUID in response to an initial signal call. The UUID is persisted on local SDK storage and is sent by the SDK to Audience Manager in all subsequent signal requests.

If you are using the Experience Cloud ID \(ECID\) Service \(formerly MCID\), the ECID and other custom identifiers for the same visitor are sent with each signal request. The visitor profile that is returned by Audience Manager is saved in SDK local storage and is updated with subsequent signal calls.

ℹ️ For more information about the UUID and other Audience Manager identifiers, see [Index of IDs in Audience Manager](https://marketing.adobe.com/resources/help/en_US/aam/ids-in-aam.html).


**Syntax**

```swift
static func signalWithData(data: [String: String], completion: @escaping ([String: String]?, Error?) -> Void) 
```

**Examples**

**Swift**

```swift
Audience.signalWithData(data: ["trait": "trait value"]) { (traits, error) in
  if error != nil {
     // handle the error here
     } else {
     // handle the returned visitorProfile here
     }
}
```

**Objective-C**

```objective-c
NSDictionary *traits = @{@"key1":@"value1",@"key2":@"value2"};
[AEPMobileAudience signalWithData:traits completion:^(NSDictionary<NSString *,NSString *> * _Nullable visitorProfile, NSError* _Nullable error) {
  if (error) {
     // handle the error here
     } else {
     // handle the returned visitorProfile dictionary here
     }
}];
```



## reset

This API helps you reset the Audience Manager UUID and purges the current visitor profile.

ℹ️ For more information about the UUID, the DPID, the DPUUID and other Audience Manager identifiers, see [Index of IDs in Audience Manager](https://marketing.adobe.com/resources/help/en_US/aam/ids-in-aam.html).

**Syntax**

```swift
static func reset()
```

**Examples**

**Swift**

```swift
Audience.reset()
```

**Objective-C**

```objective-c
[AEPMobileAudience reset]
```

# Related Project

## AEP SDK Compatibility for iOS

| Project                                                      | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [AEP SDK Compatibility for iOS](https://github.com/adobe/aepsdk-compatibility-ios) | Contains code that bridges `ACPAudience` implementations into the AEP SDK runtime. |


platform :ios, '12.0'
use_frameworks!

workspace 'AEPAudience'
project 'AEPAudience.xcodeproj'

pod 'SwiftLint', '0.52.0'

def core_pods
  pod 'AEPCore', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'staging'
  pod 'AEPServices', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'staging'
  pod 'AEPRulesEngine', :git => 'https://github.com/adobe/aepsdk-rulesengine-ios.git', :branch => 'staging'
end

target 'AEPAudience' do
  core_pods
end

target 'AEPAudienceTests' do
  core_pods
  pod 'AEPIdentity', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'staging'
end

target 'AudienceSampleApp' do
  core_pods
  pod 'AEPIdentity', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'staging'
  pod 'AEPLifecycle', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'staging'
end

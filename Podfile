platform :ios, '15.0'
use_frameworks!

workspace 'AEPAudience'
project 'AEPAudience.xcodeproj'

pod 'SwiftLint', '0.52.0'

def core_pods
  pod 'AEPCore'
  pod 'AEPServices'
  pod 'AEPRulesEngine'
end

target 'AEPAudience' do
  core_pods
end

target 'AEPAudienceTests' do
  core_pods
  pod 'AEPIdentity'
end

target 'AudienceSampleApp' do
  core_pods
  pod 'AEPIdentity'
  pod 'AEPLifecycle'
end

post_install do |pi|
  pi.pods_project.targets.each do |t|
    t.build_configurations.each do |bc|
      bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end

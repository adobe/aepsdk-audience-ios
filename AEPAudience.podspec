Pod::Spec.new do |s|
  s.name             = "AEPAudience"
  s.version          = "4.0.1"
  s.summary          = "Audience Manager library for Adobe Experience Platform Mobile SDK. Written and maintained by Adobe."
  s.description      = <<-DESC
                        The Audience Manager library provides APIs that allow use of the Audience Manager product in the Adobe Experience Platform SDK.
                        DESC
  s.homepage         = "https://github.com/adobe/aepsdk-audience-ios"
  s.license          = 'Apache V2'
  s.author           = "Adobe Experience Platform SDK Team"
  s.source           = { :git => "https://github.com/adobe/aepsdk-audience-ios", :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'

  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }

  s.dependency 'AEPCore', '>= 4.0.0', '< 5.0.0'
  s.dependency 'AEPIdentity', '>= 4.0.0', '< 5.0.0'
  s.dependency 'AEPServices', '>= 4.0.0', '< 5.0.0'

  s.source_files          = 'AEPAudience/Sources/*.swift'


end

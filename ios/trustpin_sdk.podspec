Pod::Spec.new do |spec|
  spec.name             = 'trustpin_sdk'
  spec.version          = '4.0.0'
  spec.summary          = 'Flutter plugin for TrustPin SSL certificate pinning SDK'
  spec.description      = <<-DESC
Flutter plugin for TrustPin SSL certificate pinning SDK providing secure certificate validation.
                       DESC
  spec.homepage         = 'https://github.com/trustpin-cloud/flutter.sdk'
  spec.license          = { :file => '../LICENSE' }
  spec.author           = { 'TrustPin' => 'support@trustpin.cloud' }
  spec.source           = { :git => 'https://github.com/trustpin-cloud/flutter.sdk' }
  spec.source_files = 'trustpin_sdk/Sources/trustpin_sdk/**/*.swift'
  spec.dependency 'Flutter'
  spec.dependency 'TrustPinKit', '4.0.0'

  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "13.0"
  spec.watchos.deployment_target = "7.0"
  spec.tvos.deployment_target = "13.0"
  spec.visionos.deployment_target = "2.0"

  # Flutter.framework does not contain a i386 slice.
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  spec.swift_version = "6.1"

  spec.frameworks = "Foundation", "Security"

  spec.documentation_url = 'https://trustpin-cloud.github.io/flutter.sdk'
  spec.social_media_url = 'https://trustpin.cloud'
end

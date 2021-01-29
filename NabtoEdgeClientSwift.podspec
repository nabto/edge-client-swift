Pod::Spec.new do |s|
  s.name         = 'NabtoEdgeClientSwift'
  s.version      = "0.9.4"
  s.summary      = "Nabto Edge Client for Swift"
  s.description  = <<-DESC
This pod installs the high level Nabto Edge Client for Swift: It wraps the most common functionality of the low-level ANSI C Nabto Edge Client SDK (provided in the NabtoEdgeClientApi pod).

The Nabto Edge communication platform enables you to establish direct connections from a client to even the most resource constrained devices, regardless of the firewall configuration of each peer - a P2P middleware that supports IoT well.

The platform has been designed from the ground and up with strong security as a focal point. All in all, it enables vendors to create simple, high performant and secure solutions for their Internet connected products with very little effort.

The Nabto Edge platform supersedes the Nabto Micro platform with many new features and capabilities. Read more about Nabto Edge on https://docs.nabto.com
DESC
  s.homepage         = 'https://docs.nabto.com'
  s.license      = { :type => 'Commercial', :file => 'NabtoEdgeClient.xcframework/LICENSE' }
  s.source           = { :http => "https://downloads.nabto.com/assets/edge/ios/nabto-client-swift/#{s.version}/NabtoEdgeClient.xcframework.zip"}
  #s.source           = { :http => "http://localhost:8081/pods/NabtoEdgeClient.xcframework.zip"}
  s.author           = { 'nabto' => 'apps@nabto.com' }
  s.vendored_frameworks = 'NabtoEdgeClient.xcframework'
  s.platform = :ios
  s.ios.preserve_paths = 'NabtoEdgeClient.xcframework'
  s.ios.libraries = 'c++', 'stdc++'
  s.ios.deployment_target = '12.0'

  # no arm64 simulator support yet in core api (https://github.com/CocoaPods/CocoaPods/issues/10104)
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

end

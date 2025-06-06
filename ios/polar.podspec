#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint polar.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'polar'
  s.version          = '0.0.1'
  s.summary          = 'Plugin wrapper for the Polar SDK'
  s.description      = <<-DESC
Plugin wrapper for the Polar SDK
                       DESC
  s.homepage         = 'https://github.com/Rexios80/polar'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rexios' => 'rexios@rexios.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'PolarBleSdk', '~> 6.3.0'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end

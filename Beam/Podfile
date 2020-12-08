platform :osx, '10.15'
use_frameworks!

inhibit_all_warnings!

def app_pods
  pod 'Down'
  pod 'Alamofire', '5.0.0.beta.6'
  pod 'JWTDecode'
  pod 'CocoaLumberjack/Swift'
  pod 'Sentry'
end

target 'Beam' do
  pod 'SwiftLint'
  app_pods
end

target 'BeamTests' do
  pod 'Fakery'
end

target 'BeamUITests' do
  app_pods
end

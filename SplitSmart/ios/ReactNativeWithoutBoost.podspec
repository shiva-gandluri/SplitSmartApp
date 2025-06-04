require 'json'

package = JSON.parse(File.read(File.join(__dir__, '../node_modules/react-native/package.json')))

Pod::Spec.new do |s|
  s.name         = 'ReactNativeWithoutBoost'
  s.version      = package['version']
  s.summary      = 'React Native without Boost dependency'
  s.license      = package['license']
  s.homepage     = 'https://reactnative.dev/'
  s.authors      = 'Facebook'
  s.platforms    = { :ios => '12.4' }
  s.source       = { :git => 'https://github.com/facebook/react-native.git', :tag => "v#{s.version}" }
  
  # Core React Native dependencies
  s.dependency 'React-Core', s.version
  s.dependency 'React-Core/DevSupport', s.version
  s.dependency 'React-RCTActionSheet', s.version
  s.dependency 'React-RCTAnimation', s.version
  s.dependency 'React-RCTBlob', s.version
  s.dependency 'React-RCTImage', s.version
  s.dependency 'React-RCTLinking', s.version
  s.dependency 'React-RCTNetwork', s.version
  s.dependency 'React-RCTSettings', s.version
  s.dependency 'React-RCTText', s.version
  s.dependency 'React-RCTVibration', s.version
  s.dependency 'React-cxxreact', s.version
  s.dependency 'React-jsi', s.version
  s.dependency 'React-jsiexecutor', s.version
  s.dependency 'React-jsinspector', s.version
  s.dependency 'Yoga', '~> 1.14.0'
  
  # Exclude boost from React-cxxreact and React-jsi
  s.pre_install do |installer|
    installer.pod_targets.each do |pod|
      if pod.name == 'React-cxxreact' || pod.name == 'React-jsi'
        pod.dependencies.delete_if { |d| d.name == 'boost' }
      end
    end
  end
end

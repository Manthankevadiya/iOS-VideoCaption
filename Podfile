# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'iOS-VideoCaption' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for iOS-VideoCaption
pod "Hero"

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
#      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = 'arm64'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      
      if config.base_configuration_reference.is_a? Xcodeproj::Project::Object::PBXFileReference
        xcconfig_path = config.base_configuration_reference.real_path
        content = IO.read(xcconfig_path).gsub("DT_TOOLCHAIN_DIR", "TOOLCHAIN_DIR")
        IO.write(xcconfig_path, content)
      end
    end
  end
end

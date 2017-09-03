source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'TrueNorth' do
    pod 'AffdexSDK-iOS'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        if (target.name == "AWSCore") || (target.name == 'AWSKinesis')
            target.build_configurations.each do |config|
                config.build_settings['BITCODE_GENERATION_MODE'] = 'bitcode'
            end
        end
    end
end

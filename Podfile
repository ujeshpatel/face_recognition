# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
  use_frameworks!
target 'PersonRecognize' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks


pod 'TensorFlow-experimental'
pod 'FaceCropper'
pod 'Alamofire'
pod 'SkyFloatingLabelTextField', '~> 3.0'
pod 'IQKeyboardManagerSwift'
pod 'MBProgressHUD', '~> 1.2.0'
pod 'RealmSwift'
pod 'Firebase/Core'
pod 'Firebase/Database'
pod 'Firebase/Storage'
pod 'ProgressHUD'
pod 'SDWebImage'
pod 'RxSwift'
pod 'RxCocoa'
end

post_install do |installer|
    installer.generated_projects.each do |project|
        project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.6'
            end
        end
    end
end

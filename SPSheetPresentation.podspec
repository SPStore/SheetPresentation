Pod::Spec.new do |s|
  s.name             = 'SPSheetPresentation'
  s.version          = '1.0.0'
  s.summary          = 'iOS bottom sheet presentation library with detents and scroll coordination.'
  s.description      = <<-DESC
SheetPresentation 是一个 iOS 底部抽屉展示库，支持多档位、ScrollView 联动、交互式 dismiss、
侧滑返回、浮动样式和自定义转场动画。
  DESC
  s.homepage         = 'https://github.com/SPStore/SheetPresentation'
  s.license          = { :type => 'MIT' }
  s.author           = { '乐升平' => 'lesp163@163.com' }
  s.source           = { :git => 'https://github.com/SPStore/SheetPresentation.git', :tag => s.version.to_s }

  s.platform         = :ios, '13.0'
  s.swift_versions   = ['5.9']
  s.requires_arc     = true
  s.module_name      = 'SheetPresentation'

  s.source_files     = 'Sources/SheetPresentation/**/*.swift'
  s.resources        = 'Sources/PrivacyInfo.xcprivacy'

  s.frameworks       = 'UIKit'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end

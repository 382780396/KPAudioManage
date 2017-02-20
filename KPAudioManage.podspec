
Pod::Spec.new do |s|

  s.name         = "KPAudioManage"
  s.version      = "0.0.1"
  s.summary      = "KPAudioManage 问答和协议讲解公共组件"

  s.homepage     = "https://github.com/TRZXDev/KPAudioManage.git"
 
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Rhino" => "502244672@qq.com" }

  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/TRZXDev/KPAudioManage.git", :tag => s.version.to_s }

  s.source_files = "KPAudioManage/KPAudioManage/*.{h,m}"
  
  s.dependency 'AFNetworking'

  s.requires_arc = true

end

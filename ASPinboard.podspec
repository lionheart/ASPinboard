Pod::Spec.new do |s|
  s.name         = "ASPinboard"
  s.platform     = :ios
  s.ios.deployment_target = "7.0"
  s.version      = "0.0.1"
  s.homepage     = "lionheartsw.com"
  s.license      = 'Apache 2.0'
  s.author       = { "Dan Loewenherz" => "dan@lionheartsw.com" }
  s.source       = { :git => "https://github.com/lionheart/ASPinboard.git" }

  s.source_files = 'ASPinboard/*.{h,m}'
  s.requires_arc = true
  s.public_header_files = "ASPinboard/ASPinboard.h"
  s.dependency 'hpple', '~> 0.2.0'
end


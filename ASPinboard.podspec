Pod::Spec.new do |s|
  s.name         = "ASPinboard"
  s.version      = "0.0.1"
  s.homepage     = "lionheartsw.com"
  s.license      = 'Apache 2.0'
  s.author       = { "Dan Loewenherz" => "dan@lionheartsw.com" }
  s.source       = { :git => "https://github.com/lionheart/ASPinboard.git" }

  s.source_files = 'ASPinboard/*.{h,m}'
  s.requires_arc = true
  s.ios.library = 'xml2.2'
end


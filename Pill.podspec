Pod::Spec.new do |s|
    s.name             = 'Pill'
    s.version          = '0.9'
    s.summary          = 'A streamlined Future<Value, Error> implementation'
    s.homepage         = 'https://github.com/kean/Pill'
    s.license          = 'MIT'
    s.author           = 'Alexander Grebenyuk'
    s.social_media_url = 'https://twitter.com/a_grebenyuk'
    s.source           = { :git => 'https://github.com/kean/Pill.git', :tag => s.version.to_s }

    s.ios.deployment_target = '9.0'
    s.watchos.deployment_target = '2.0'
    s.osx.deployment_target = '10.11'
    s.tvos.deployment_target = '9.0'

    s.source_files  = 'Sources/**/*'
end

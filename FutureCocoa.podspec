Pod::Spec.new do |s|
    s.name             = 'FutureCocoa'
    s.version          = '0.10'
    s.summary          = 'A streamlined Future<Value, Error> implementation'
    s.homepage         = 'https://github.com/kean/FutureX'
    s.license          = 'MIT'
    s.author           = 'Alexander Grebenyuk'
    s.social_media_url = 'https://twitter.com/a_grebenyuk'
    s.source           = { :git => 'https://github.com/kean/FutureX.git', :tag => s.version.to_s }

    s.ios.deployment_target = '9.0'

    s.source_files  = 'FutureCocoa/**/*'

    s.dependency 'FutureX'
end

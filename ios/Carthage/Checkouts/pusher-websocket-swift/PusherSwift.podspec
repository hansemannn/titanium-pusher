Pod::Spec.new do |s|
  s.name             = 'PusherSwift'
  s.version          = '6.1.0'
  s.summary          = 'A Pusher client library in Swift'
  s.homepage         = 'https://github.com/pusher/pusher-websocket-swift'
  s.license          = 'MIT'
  s.author           = { "Hamilton Chapman" => "hamchapman@gmail.com" }
  s.source           = { git: "https://github.com/pusher/pusher-websocket-swift.git", tag: s.version.to_s }
  s.social_media_url = 'https://twitter.com/pusher'

  s.requires_arc = true
  s.source_files = 'Sources/*.swift'

  s.dependency 'CryptoSwift', '~> 0.9.0'
  s.dependency 'ReachabilitySwift', '~> 4.1.0'
  s.dependency 'TaskQueue', '~> 1.1.1'
  s.dependency 'Starscream', '~> 3.0.5'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
end

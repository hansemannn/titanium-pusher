//
//  TiPusherExampleProxy.swift
//  titanium-pusher
//
//  Created by Hans Knöchel
//  Copyright (c) 2019-present Lambus GmbH. All rights reserved.
//

import TitaniumKit
import PusherSwift

@objc(TiPusherModule)
class TiPusherModule: TiModule {

  private var pusher: Pusher?
  
  func moduleGUID() -> String {
    return "e5011752-5cb4-47e7-b3b8-9a03bbca3e09"
  }
  
  override func moduleId() -> String! {
    return "ti.pusher"
  }

  @objc(initialize:)
  func initialize(arguments: Array<Any>?) {
    guard let arguments = arguments, let params = arguments[0] as? [String: Any] else { return }
    guard let key = params["key"] as? String else { return }
    let proxyOptions = params["options"] as? [String: Any] ?? [:]

    let options = PusherClientOptions(
      host: .cluster(proxyOptions["cluster"] as? String ?? "eu"),
      useTLS: true
    )

    if let authEndpoint = proxyOptions["authEndpoint"] as? String,
       let accessToken = proxyOptions["accessToken"] as?  String {
      let headers = proxyOptions["headers"] as? [String: String]
      
      options.authMethod = AuthMethod.authRequestBuilder(authRequestBuilder: TiAuthRequestBuilder(authURL: authEndpoint,
                                                                                                  accessToken: accessToken,
                                                                                                  headers: headers))
    }
    
    pusher = Pusher(
      key: key,
      options: options
    )

    pusher?.delegate = self
  }
  
  @objc(connect:)
  func connect(unused: Any) {
    guard let pusher = pusher else { return }
    pusher.connect()
  }
  
  @objc(disconnect:)
  func disconnect(unused: Any) {
    guard let pusher = pusher else { return }
    pusher.disconnect()
  }
  
  @objc(subscribe:)
  func subscribe(arguments: Array<Any>?) -> TiPusherChannelProxy? {
    guard let arguments = arguments, let channelName = arguments[0] as? String else { return nil }
    guard let pusher = pusher else { return nil }
    
    let channel = pusher.subscribe(channelName: channelName)
    return TiPusherChannelProxy()._init(withPageContext: pageContext, channel: channel)
  }
}

extension TiPusherModule: PusherDelegate {
  func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
    if let error = error {
      fireEvent("error", with: ["error": error.localizedDescription])
    }
  }
  
  func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
    fireEvent("connectionchange", with: ["old": old.rawValue, "new": new.rawValue])
  }
}

class TiAuthRequestBuilder: AuthRequestBuilderProtocol {
  let authURL: String
  let accessToken: String
  let headers: [String: String]?
  
  init(authURL: String, accessToken: String, headers: [String: String]?) {
    self.authURL = authURL
    self.accessToken = accessToken
    self.headers = headers
  }
  
  func requestFor(socketID: String, channelName: String) -> URLRequest? {
    var request = URLRequest(url: URL(string: authURL)!)
    request.httpMethod = "POST"
    request.httpBody = "socket_id=\(socketID)&channel_name=\(channelName)".data(using: String.Encoding.utf8)
    request.setValue(accessToken, forHTTPHeaderField: "Authorization")

    // Apply custom headers if present
    if let headers = headers {
      for key in headers.keys {
        request.setValue(headers[key], forHTTPHeaderField: key)
      }
    }

    return request
  }
}

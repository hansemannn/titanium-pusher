//
//  TiPusherExampleProxy.swift
//  titanium-pusher
//
//  Created by Hans Knöchel
//  Copyright (c) 2019-present Lambus GmbH. All rights reserved.
//

import UIKit
import PusherSwift
import TitaniumKit

@objc(TiPusherChannelProxy)
class TiPusherChannelProxy: TiProxy {
  
  private var channel: PusherChannel?

  func _init(withPageContext context: TiEvaluator!, channel: PusherChannel) -> TiPusherChannelProxy! {
    super._init(withPageContext: context)

    self.channel = channel
    
    return self
  }
  
  @objc(bind:)
  func bind(arguments: Array<Any>?) {
    guard let arguments = arguments, let eventName = arguments[0] as? String else { return }
    guard let channel = channel else { return }
    
    let _ = channel.bind(eventName: eventName, eventCallback: { (data: Any?) -> Void in
      if let data = data as? [String : AnyObject] {
        self.fireEvent("data", with: ["data" : data])
      }
    })
  }
  
  @objc(unbindAll:)
  func unbindAll(unused: Any) {
    guard let channel = channel else { return }
    channel.unbindAll()
  }
  
  @objc(trigger:)
  func trigger(arguments: Array<Any>?) {
    guard let arguments = arguments, let eventName = arguments[0] as? String, let data = arguments[1] as? [String: Any] else { return }
    guard let channel = channel else { return }
  
    channel.trigger(eventName: eventName, data: data)
  }
}

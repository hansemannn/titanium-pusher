# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased](https://github.com/pusher/pusher-websocket-swift/compare/6.0.0...HEAD)

## [6.0.0](https://github.com/pusher/pusher-websocket-swift/compare/5.1.1...6.0.0) - 2018-04-04

### Added

- Client will now send a ping to the server if there has been a period of inactivity on the socket. This should help detect some disconnections that previously weren't being noticed.

### Changed

- All dependencies are now defined to be brought in using the appropriate package manager (Carthage or CocoaPods)
- Reconnection strategy has been changed to now attempt reconnecting indefinitely, with an exponential backoff but a maximum interval of 120 seconds between reconnection attempts.

### Removed

- Removed the deprecated `AuthRequestBuilderProtocol` function: `func requestFor(socketID: String, channel: PusherChannel) -> NSMutableURLRequest?`
- `reconnectingWhenNetworkBecomesReachable` connection state

## [5.1.1](https://github.com/pusher/pusher-websocket-swift/compare/5.1.0...5.1.1) - 2018-01-22

### Changed
- Updated Starscream and CryptoSwift based code. Starscream is at roughly 3.0.4 and CryptoSwift at roughly 0.8.1.

## [5.1.0](https://github.com/pusher/pusher-websocket-swift/compare/5.0.1...5.1.0) - 2017-11-23

### Added
- [`setSubscriptions`](https://pusher.com/docs/push_notifications/reference/client_api#put-v1clientsclientidinterests) method.

## 5.0.1

* Swift 4 support.
* Updated CryptoSwift-based code.

## 5.0.0

* Swift 3.2 support (requires Xcode 9+).

## 4.2.1

* Updated Starscream dependency (commit SHA 789264eef). Fixes #115.

## 4.2.0

* Added `Authorizer` protocol that permits a new authorization method for channels requiring it (private and presence channels).

## 4.1.0

* Reverted change introduced in 4.0.2 that set up a custom callback queue for the underlying websocket
* Added the ability to provide auth values on channel subscriptions
* Updated Starscream dependency to latest version (commit SHA ee993322c)
* Encode channel names to be consistent with other libraries

## 4.0.2 (pulled - upgrade to 4.1.0+)

* Fixed `members` property not being set before `subscription_succeeded` event callbacks were called for presence channels ([@ichibod](https://github.com/ichibod))

## 4.0.1

* Fixed memory leak issues with `PusherConnection` and `PusherDelegate` ([@anlaital](https://github.com/anlaital))
* Deprecated `requestFor` in `AuthRequestBuilderProtocol` that returns `NSMutableURLRequest?`
* Added `requestFor` in `AuthRequestBuilderProtocol` that takes a `channelName` `String` instead of a `PusherChannel` instance, and returns `URLRequest?` ([@Noobish1](https://github.com/Noobish1))

## 4.0.0

* Made code required for push notifications available on macOS platform (i.e. push notifications work on macOS!) ([@jameshfisher](https://github.com/jameshfisher))
* Removed `PusherConnectionDelegate` and moved all delegate functions into unified `PusherDelegate`
* Renamed most delegate functions:
  - `didRegisterForPushNotifications(clientId: String)` -> `registeredForPushNotifications(clientId: String)`
  - `didSubscribeToInterest(named name: String)` -> `subscribedToInterest(name: String)`
  - `didUnsubscribeFromInterest(named name: String)` -> `unsubscribedFromInterest(name: String)`
  - `connectionStateDidChange?(from: oldState, to: newState)` -> `changedConnectionState(from old: ConnectionState, to new: ConnectionState)`
  - `subscriptionDidSucceed?(channelName: channelName)` -> `subscribedToChannel(name: String)`
  - `subscriptionDidFail?(channelName: channelName, response: response, data: data, error: error)` -> `failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?)`
* Added macOS Example Swift project that contains an example macOS app to demo push notifications (requires setting up with your own Pusher app)
* Update CryptoSwift and Starscream dependencies
* Made `NativePusher` not be a singleton anymore
* Fixed `taskQueue` crash (#96)

## 3.2.0

* Authentication requests that result in any status code other that 200 or 201 are now treated as failures (previously any 2xx status code was treated as a success)
* Add a `findPresence` function to the `PusherPresenceChannel` class
* Make docs for working with presence channels much clearer

## 3.1.0

* Fix bug in NativePusher where subscription modification requests would fail but not call the appropriate branch of the `guard` statement
* Add `PusherDelegate`, which includes optional functions related to Push Notification-related events
* Added TaskQueue and refactored how subscribe / unsubscribe events are sent to the Push Notifications service (to make it thread-safe)
* Added tests for NativePusher-related code paths

## 3.0.0

* Update to work with Swift 3
* Rewrote all tests using XCTest
* Remove all need for Podfile / Cartfile when building PusherSwift locally
* Combine different builds into single target
* Merge in native notification code into main branch (push-notifications branch)
* Consolidate connection-related handlers / callbacks into `PusherConnectionDelegate`
* Make `requestFor` in `AuthRequestBuilderProtocol` able to fail
* Rename `PresencePusherChannel` -> `PusherPresenceChannel`
* Rename `PresenceChannelMember` -> `PusherPresenceChannelMember`
* Rename `internal` `authMethod` enum case to `inline`
* Add Obj-C compatibility
* Add iOS Obj-C example app
* Add `subscribeToPresenceChannel` method

## 2.0.1

* Fix potential forceful unwrapping of a nil in debug logging when reconnecting (thanks to [@psycotica0](https://github.com/psycotica0) for the spot)

## 2.0.0

* Made the `Pusher` initializer take an instance of a `PusherClientOptions` struct ([@Noobish1](https://github.com/Noobish1))
* Authenticating channels can now be achieved by: specifying an auth endpoint, providing an auth request builder (which conforms to the `AuthRequestBuilder` protocol), or by providing your app's secret (not for production) ([@Noobish1](https://github.com/Noobish1))
* Made the code Swiftier in general, e.g. `PusherChannelType` enum ([@Noobish1](https://github.com/Noobish1))
* More robust reconnect (#66 - thanks to [@psycotica0](https://github.com/psycotica0) for review)
* Added two new connection state cases: `Reconnecting` and `ReconnectingWhenNetworkBecomesReachable`
* Added `reconnectAttemptsMax` and `maxReconnectGapInSeconds` for tweaking specifics of reconnection logic
* Receiving Pusher-related errors by binding to the event name `pusher:error` on the client now works

## 1.0.0

* Add `onMemberAdded`, `onMemberRemoved`, `findMember`, and `me` functions to PusherPresenceChannel class
* Bring CryptoSwift, Starscream and Reachability dependencies inside the PusherSwift library
* Update Quick and Nimble dependencies to remove warnings for Swift compatibility
* Use cocoapods version 1.0.0 on Travis
* Split up `PusherSwift.swift` and `PusherSwiftTests.swift` into components
* Add inline documentation throughout codebase
* Added `debugLogger` option to client
* Handling of `pusher:error` messages now works as it should have done all along
* Building with Carthage now now longer requires a `pod install` to make it work
* Fix bug in `ConnectionStateChangeDelegate`
* Pass authorization errors to client ([@psycotica0](https://github.com/psycotica0))

## 0.3.0

* Use cocoapods version 1.0.0.beta.6 to make builds work on Travis
* Use Xcode 7.3 image and updated simulators on Travis
* Update CryptoSwift to 0.3.1 and Starscream to 1.1.3 (largely for Swift 2.2 compatibility)
* Add ConnectionStateChangeDelegate and associated docs & tests

## 0.2.4

* Use cocoapods version 1.0.0.beta.5 to make builds work on Travis
* Update CryptoSwift to 0.2.3
* Update Starscream to 1.1.2
* Add `cluster` option to client initialiser options dictionary
* Fix autoreconnect bugs ([@bdolman](https://github.com/bdolman))
* Make `pusher:subscription_succeeded` event accessible ([@bdolman](https://github.com/bdolman))

## 0.2.3

* Make `unsentEvents` an array instead of a dictionary (fixes #29)

## 0.2.2

* Fix building for Carthage
* Update `TARGETED_DEVICE_FAMILY` for tvOS target to be correct (`3`)

## 0.2.1

* Remove Pods directory from repo
* Change iOS deployment target to 8.0
* Use cocoapods version 1.0.0.beta.2 to make builds work on Travis

## 0.2.0

* Add platform-specific builds for iOS, tvOS, OSX
* Add build and test schemes for platform-specific builds
* Update Starscream to 1.1.1
* POST auth parameter with HTTP Body ([@ngs](https://github.com/ngs))

## 0.1.7

* Add support for tvOS as platform ([@goose2460](https://github.com/goose2460))
* Update CryptoSwift to 0.2.2 ([@goose2460](https://github.com/goose2460))
* Update ReachabilitySwift to 2.3.3 ([@goose2460](https://github.com/goose2460))
* Rename `Sources` back to `Source`

## 0.1.6

* Fixed build errors with Carthage
* Rename `Source` to `Sources` in order to work with Swift Package Manager (in principle)
* Make headers for PusherSwift and PusherSwiftTests targets public

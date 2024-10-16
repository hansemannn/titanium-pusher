import Foundation

// swiftlint:disable nesting

enum Constants {

    enum API {
        static let defaultHost          = "ws.pusherapp.com"
        static let pusherDomain         = "pusher.com"
    }

    enum ChannelTypes {
        static let presence         = "presence"
        static let `private`        = "private"
        static let privateEncrypted = "private-encrypted"
    }

    enum Events {
        enum Pusher {
            static let connectionEstablished    = "pusher:connection_established"
            static let error                    = "pusher:error"
            static let subscribe                = "pusher:subscribe"
            static let unsubscribe              = "pusher:unsubscribe"
            static let subscriptionError        = "pusher:subscription_error"
            static let subscriptionSucceeded    = "pusher:subscription_succeeded"
        }

        enum PusherInternal {
            static let memberAdded              = "pusher_internal:member_added"
            static let memberRemoved            = "pusher_internal:member_removed"
            static let subscriptionSucceeded    = "pusher_internal:subscription_succeeded"
            static let subscriptionCount        = "pusher_internal:subscription_count"
        }
    }

    enum EventTypes {
        static let client           = "client"
        static let pusher           = "pusher"
        static let pusherInternal   = "pusher_internal"
    }

    enum JSONKeys {
        static let activityTimeout   = "activity_timeout"
        static let auth              = "auth"
        static let channel           = "channel"
        static let channelData       = "channel_data"
        static let ciphertext        = "ciphertext"
        static let code              = "code"
        static let data              = "data"
        static let event             = "event"
        static let hash              = "hash"
        static let message           = "message"
        static let nonce             = "nonce"
        static let presence          = "presence"
        static let socketId          = "socket_id"
        static let sharedSecret      = "shared_secret"
        static let userId            = "user_id"
        static let userInfo          = "user_info"
        static let subscriptionCount = "subscription_count"
    }
}

import Foundation

@objcMembers
open class PusherChannel: NSObject {
    // Access via queue for thread safety if user binds/unbinds events to a channel off the main queue
    // (Concurrent reads are allowed. Writes using `.barrier` so queue waits for completion before continuing)
    private let eventHandlersQueue = DispatchQueue(label: "com.pusher.pusherswift-channel-event-handlers-\(UUID().uuidString)",
                                                   attributes: .concurrent)
    private var eventHandlersInternal = [String: [EventHandler]]()
    open var eventHandlers: [String: [EventHandler]] {
        get {
            return eventHandlersQueue.sync { eventHandlersInternal }
        }
        set {
            eventHandlersQueue.async(flags: .barrier) { self.eventHandlersInternal = newValue }
        }
    }

    private var _subscriptionCount: Int?
    public var subscriptionCount: Int? {
        get { return _subscriptionCount }
    }

    open var subscribed = false
    public let name: String
    open weak var connection: PusherConnection?
    open var unsentEvents = [QueuedClientEvent]()
    public let type: PusherChannelType
    public var auth: PusherAuth?
    open var onSubscriptionCountChanged: ((Int) -> Void)?

    // Wrap accesses to the decryption key in a serial queue because it will be accessed from multiple threads
    @nonobjc private var decryptionKeyQueue = DispatchQueue(label: "com.pusher.pusherswift-channel-decryption-key-\(UUID().uuidString)",
                                                            attributes: .concurrent)
    @nonobjc private var decryptionKeyInternal: String?
    @nonobjc internal var decryptionKey: String? {
        get {
            return decryptionKeyQueue.sync { decryptionKeyInternal }
        }
        set {
            decryptionKeyQueue.async(flags: .barrier) { self.decryptionKeyInternal = newValue }
        }
    }

    /**
        Initializes a new PusherChannel with a given name and connection

        - parameter name:       The name of the channel
        - parameter connection: The connection that this channel is relevant to
        - parameter auth:       A PusherAuth value if subscription is being made to an
                                authenticated channel without using the default auth methods

        - returns: A new PusherChannel instance
    */
    public init(name: String, connection: PusherConnection, auth: PusherAuth? = nil, onSubscriptionCountChanged: ((Int) -> Void)? = nil) {
        self.name = name
        self.connection = connection
        self.auth = auth
        self.type = PusherChannelType(name: name)
        self.onSubscriptionCountChanged = onSubscriptionCountChanged
    }

    internal func updateSubscriptionCount(count: Int) {
        self._subscriptionCount = count
        self.onSubscriptionCountChanged?(count)
    }

    /**
     Binds a callback to a given event name, scoped to the PusherChannel the function is
     called on

     - parameter eventName:     The name of the event to bind to
     - parameter eventCallback: The function to call when a new event is received. The callback
                                receives a PusherEvent, containing the event's data payload and
                                other properties.

     - returns: A unique callbackId that can be used to unbind the callback at a later time
     */
    @discardableResult open func bind(eventName: String, eventCallback: @escaping (PusherEvent) -> Void) -> String {
        let randomId = UUID().uuidString
        let eventHandler = EventHandler(id: randomId, callback: eventCallback)
        if self.eventHandlers[eventName] != nil {
            self.eventHandlers[eventName]?.append(eventHandler)
        } else {
            self.eventHandlers[eventName] = [eventHandler]
        }
        return randomId
    }

    /**
        Unbinds the callback with the given callbackId from the given eventName, in the scope
        of the channel being acted upon

        - parameter eventName:  The name of the event from which to unbind
        - parameter callbackId: The unique callbackId string used to identify which callback to unbind
    */
    open func unbind(eventName: String, callbackId: String) {
        guard let eventSpecificHandlers = self.eventHandlers[eventName] else {
            return
        }

        self.eventHandlers[eventName] = eventSpecificHandlers.filter({ $0.id != callbackId })
    }

    /**
        Unbinds all callbacks from the channel
    */
    open func unbindAll() {
        self.eventHandlers = [:]
    }

    /**
        Unbinds all callbacks for the given eventName from the channel

        - parameter eventName:  The name of the event from which to unbind
    */
    open func unbindAll(forEventName eventName: String) {
        self.eventHandlers[eventName] = []
    }

    /**
        Calls the appropriate callbacks for the given eventName in the scope of the acted upon channel

        - parameter event: The event received from the websocket
    */
    open func handleEvent(event: PusherEvent) {
        guard let eventHandlerArray = self.eventHandlers[event.eventName] else {
            return
        }

        for eventHandler in eventHandlerArray {
            // swiftlint:disable:next force_cast
            eventHandler.callback(event.copy() as! PusherEvent)
        }
    }

    /**
        If subscribed, immediately call the connection to trigger a client event with the given
        eventName and data, otherwise queue it up to be triggered upon successful subscription

        - parameter eventName: The name of the event to trigger
        - parameter data:      The data to be sent as the message payload
    */
    open func trigger(eventName: String, data: Any) {
        if PusherChannel.isEncrypted(name: self.name) {
            let context = "'\(self.name)'. Client event '\(eventName)' will not be sent"
            Logger.shared.error(for: .clientEventsNotSupported,
                                context: context)
            return
        }

        if subscribed {
            connection?.sendEvent(event: eventName, data: data, channel: self)
        } else {
            unsentEvents.insert(QueuedClientEvent(name: eventName, data: data), at: 0)
        }
    }
}

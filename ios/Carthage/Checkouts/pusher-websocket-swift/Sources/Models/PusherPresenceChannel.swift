import Foundation

public typealias PusherUserInfoObject = [String: AnyObject]

@objcMembers
@objc open class PusherPresenceChannel: PusherChannel {
    open var members: [PusherPresenceChannelMember]
    open var onMemberAdded: ((PusherPresenceChannelMember) -> Void)?
    open var onMemberRemoved: ((PusherPresenceChannelMember) -> Void)?
    open var myId: String?

    /**
        Initializes a new PusherPresenceChannel with a given name, connection, and optional
        member added and member removed handler functions

        - parameter name:            The name of the channel
        - parameter connection:      The connection that this channel is relevant to
        - parameter auth:            A PusherAuth value if subscription is being made to an
                                     authenticated channel without using the default auth methods
        - parameter onMemberAdded:   A function that will be called with information about the
                                     member who has just joined the presence channel
        - parameter onMemberRemoved: A function that will be called with information about the
                                     member who has just left the presence channel

        - returns: A new PusherPresenceChannel instance
    */
    init(
        name: String,
        connection: PusherConnection,
        auth: PusherAuth? = nil,
        onMemberAdded: ((PusherPresenceChannelMember) -> Void)? = nil,
        onMemberRemoved: ((PusherPresenceChannelMember) -> Void)? = nil
    ) {
        self.members = []
        self.onMemberAdded = onMemberAdded
        self.onMemberRemoved = onMemberRemoved
        super.init(name: name, connection: connection, auth: auth)
    }

    /**
        Add information about the member that has just joined to the members object
        for the presence channel and call onMemberAdded function, if provided

        - parameter memberJSON: A dictionary representing the member that has joined
                                the presence channel
    */
    internal func addMember(memberJSON: [String: Any]) {
        let member: PusherPresenceChannelMember

        if let userId = memberJSON[Constants.JSONKeys.userId] as? String {
            if let userInfo = memberJSON[Constants.JSONKeys.userInfo] as? PusherUserInfoObject {
                member = PusherPresenceChannelMember(userId: userId, userInfo: userInfo as AnyObject?)
            } else {
                member = PusherPresenceChannelMember(userId: userId)
            }
        } else {
            if let userInfo = memberJSON[Constants.JSONKeys.userInfo] as? PusherUserInfoObject {
                member = PusherPresenceChannelMember(userId: String(describing: memberJSON[Constants.JSONKeys.userId]!),
                                                     userInfo: userInfo as AnyObject?)
            } else {
                member = PusherPresenceChannelMember(userId: String(describing: memberJSON[Constants.JSONKeys.userId]!))
            }
        }
        members.append(member)
        self.onMemberAdded?(member)
    }

    /**
        Add information about the members that are already subscribed to the presence channel to
        the members object of the presence channel

        - parameter memberHash: A dictionary representing the members that were already
                                subscribed to the presence channel
    */
    internal func addExistingMembers(memberHash: [String: AnyObject]) {
        for (userId, userInfo) in memberHash {
            let member: PusherPresenceChannelMember
            if let userInfo = userInfo as? PusherUserInfoObject {
                member = PusherPresenceChannelMember(userId: userId, userInfo: userInfo as AnyObject?)
            } else {
                member = PusherPresenceChannelMember(userId: userId)
            }
            self.members.append(member)
        }
    }

    /**
        Remove information about the member that has just left from the members object
        for the presence channel and call onMemberRemoved function, if provided

        - parameter memberJSON: A dictionary representing the member that has left the
                                presence channel
    */
    internal func removeMember(memberJSON: [String: Any]) {
        let id: String

        if let userId = memberJSON[Constants.JSONKeys.userId] as? String {
            id = userId
        } else {
            id = String(describing: memberJSON[Constants.JSONKeys.userId]!)
        }

        guard let index = self.members.firstIndex(where: { $0.userId == id }) else {
            return
        }

        let member = self.members[index]
        self.members.remove(at: index)
        self.onMemberRemoved?(member)
    }

    /**
        Set the value of myId to the value of the user_id returned as part of the authorization
        of the subscription to the channel

        - parameter channelData: The channel data obtained from authorization of the subscription
                                 to the channel
    */
    internal func setMyUserId(channelData: String) {
        guard let channelDataObject = parse(channelData: channelData),
            let userId = channelDataObject[Constants.JSONKeys.userId] else {
            return
        }

        self.myId = String(describing: userId)
    }

    /**
        Parse a string to extract the channel data object from it

        - parameter channelData: The channel data string received as part of authorization

        - returns: A dictionary of channel data
    */
    private func parse(channelData: String) -> [String: AnyObject]? {
        let data = (channelData as NSString).data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)

        do {
            if let jsonData = data,
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData,
                                                                  options: []) as? [String: AnyObject] {
                return jsonObject
            } else {
                Logger.shared.debug(for: .unableToParseStringAsJSON,
                                    context: channelData)
            }
        } catch let error as NSError {
            Logger.shared.error(for: .genericError,
                                context: error.localizedDescription)
        }
        return nil
    }

    /**
        Returns the PusherPresenceChannelMember object for the given user id

        - parameter userId: The user id of the PusherPresenceChannelMember for whom you want
                            the PusherPresenceChannelMember object

        - returns: The PusherPresenceChannelMember object for the given user id
    */
    open func findMember(userId: String) -> PusherPresenceChannelMember? {
        return self.members.first(where: { $0.userId == userId })
    }

    /**
        Returns the connected user's PusherPresenceChannelMember object

        - returns: The connected user's PusherPresenceChannelMember object
    */
    open func me() -> PusherPresenceChannelMember? {
        guard let id = self.myId else {
            return nil
        }

        return findMember(userId: id)
    }
}

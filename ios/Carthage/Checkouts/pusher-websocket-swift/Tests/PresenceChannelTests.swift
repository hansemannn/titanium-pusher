import XCTest

#if WITH_ENCRYPTION
    @testable import PusherSwiftWithEncryption
#else
    @testable import PusherSwift
#endif

class PusherPresenceChannelTests: XCTestCase {
    var pusher: Pusher!
    var socket: MockWebSocket!
    var options: PusherClientOptions!
    var stubber: StubberForMocks!

    override func setUp() {
        super.setUp()

        options = PusherClientOptions(
            authMethod: .inline(secret: "secret"),
            autoReconnect: false
        )
        pusher = Pusher(key: "key", options: options)
        socket = MockWebSocket()
        socket.delegate = pusher.connection
        pusher.connection.socket = socket
        stubber = StubberForMocks()
    }

    func testMembersObjectStoresUserIdIfAUserDataFetcherIsProvided() {
        pusher.connection.userDataFetcher = { () -> PusherPresenceChannelMember in
            return PusherPresenceChannelMember(userId: "123")
        }

        pusher.connect()
        let ex = expectation(description: "subscription succeed")
        let chan = pusher.subscribe("presence-channel") as? PusherPresenceChannel
        chan?.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            ex.fulfill()
            XCTAssertEqual(chan?.members.first!.userId, "123", "the userId should be 123")
        }
        waitForExpectations(timeout: 0.5)
    }

    func testMembersObjectStoresSocketIdIfNoUserDataFetcherIsProvided() {
        pusher.connect()

        let chan = pusher.subscribe("presence-channel") as? PusherPresenceChannel
        let ex = expectation(description: "subscription succeed")
        chan?.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            ex.fulfill()
            XCTAssertEqual(chan?.members.first!.userId, "46123.486095", "the userId should be 46123.486095")
        }
        waitForExpectations(timeout: 0.5)
    }

    func testMembersObjectStoresUserIdAndUserInfoIfAUserDataFetcherIsProvidedThatReturnsBoth() {
        pusher = Pusher(key: "testKey123", options: options)
        pusher.connection.userDataFetcher = { () -> PusherPresenceChannelMember in
            return PusherPresenceChannelMember(userId: "123", userInfo: ["twitter": "hamchapman"] as Any?)
        }
        socket.delegate = pusher.connection
        pusher.connection.socket = socket
        pusher.connect()

        let channelName = "presence-test"

        let ex = expectation(description: "subscription succeed")
        guard let chan = pusher.subscribe(channelName) as? PusherPresenceChannel else {
            return XCTFail("Couldn't subscribe to channel: \(channelName).")
        }

        chan.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            ex.fulfill()

            guard let firstUser = chan.members.first else {
               return XCTFail("User doesn't exist.")
           }

           let userId = firstUser.userId
           let userInfo = firstUser.userInfo as! [String: String]

           XCTAssertEqual(userId, "123", "the userId should be 123")
           XCTAssertEqual(userInfo, ["twitter": "hamchapman"], "the userInfo should be [\"twitter\": \"hamchapman\"]")
        }
        waitForExpectations(timeout: 0.5)
    }

    func testFindingPusherPresenceChannelMemberByUserId() {
        pusher.connect()
        let ex = expectation(description: "member added")

        var chan: PusherPresenceChannel? = nil
        let memberAdded = { (member: PusherPresenceChannelMember) in
            let member = chan!.findMember(userId: "100")

            XCTAssertEqual(member!.userId, "100", "the userId should be 100")
            XCTAssertEqual(member!.userInfo as! [String: String], ["twitter": "hamchapman"], "the userInfo should be [\"twitter\": \"hamchapman\"]")
            ex.fulfill()
        }

        chan = pusher.subscribe("presence-channel", onMemberAdded: memberAdded) as? PusherPresenceChannel
        chan?.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            let jsonDict = """
            {
                "event": "pusher_internal:member_added",
                "channel": "presence-channel",
                "data": "{\\"user_id\\":\\"100\\", \\"user_info\\":{\\"twitter\\":\\"hamchapman\\"}}"
            }
            """.removing(.newlines)
            self.pusher.connection.websocketDidReceiveMessage(socket: self.socket, text: jsonDict)
        }

        waitForExpectations(timeout: 0.5)
    }

    func testFindingTheClientsMemberObject() {
        let userId = "123"
        pusher.connection.userDataFetcher = { () -> PusherPresenceChannelMember in
            return PusherPresenceChannelMember(userId: userId, userInfo: ["friends": 0])
        }

        pusher.connect()

        let channelName = "presence-channel"

        guard let presenceChannel = pusher.subscribe(channelName: channelName) as? PusherPresenceChannel else {
            return XCTFail("Couldn't subscribe to channel: \(channelName).")
        }

        let ex = expectation(description: "subscription succeed")
        presenceChannel.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            ex.fulfill()

            guard let member = presenceChannel.me() else {
               return XCTFail("Couldn't find member with id: \(userId).")
           }

           XCTAssertEqual(member.userId, userId, "the userId should be \(userId)")
           XCTAssertEqual(member.userInfo as! [String: Int], ["friends": 0], "the userInfo should be [\"friends\": 0]")

        }
        waitForExpectations(timeout: 0.5)
    }

    func testFindingAPresenceChannelAsAPusherPresenceChannel() {
        let userId = "123"
        pusher.connection.userDataFetcher = { () -> PusherPresenceChannelMember in
            return PusherPresenceChannelMember(userId: userId, userInfo: ["friends": 0])
        }

        pusher.connect()

        let channelName = "presence-channel"

        let presenceChannel = pusher.subscribe(channelName)

        let ex = expectation(description: "subscription succeed")
        presenceChannel.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            ex.fulfill()
            guard let presenceChannel = self.pusher.connection.channels.findPresence(name: channelName) else {
                return XCTFail("Presence for channel: \(channelName) not found.")
            }

            guard let member = presenceChannel.me() else {
                return XCTFail("Couldn't find member.")
            }

            XCTAssertEqual(member.userId, userId, "the userId of the client's member object should be \(userId)")
        }
        waitForExpectations(timeout: 0.5)
    }

    func testOnMemberAddedFunctionGetsCalledWhenANewSubscriptionSucceeds() {
        let ex = expectation(description: "member added")

        pusher.connect()

        let memberAddedFunction = { (member: PusherPresenceChannelMember) -> Void in
            XCTAssertEqual(member.userId, "100", "the userId should be 100")
            ex.fulfill()
        }
        let chan = pusher.subscribe("presence-channel", onMemberAdded: memberAddedFunction) as? PusherPresenceChannel
        chan?.bind(eventName: "pusher:subscription_succeeded") { (event: PusherEvent) in
            let jsonDict = """
            {
                "event": "pusher_internal:member_added",
                "channel": "presence-channel",
                "data": "{\\"user_id\\":\\"100\\"}"
            }
            """.removing(.newlines)
            self.pusher.connection.websocketDidReceiveMessage(socket: self.socket, text: jsonDict)
        }
        waitForExpectations(timeout: 0.5)
    }

    func testOnMemberRemovedFunctionGetsCalledWhenANewSubscriptionSucceeds() {
        let ex = expectation(description: "member removed")

        pusher.connect()

        let memberRemovedFunction = { (member: PusherPresenceChannelMember) -> Void in
            XCTAssertEqual(member.userId, "100", "the userId should be 100")
            ex.fulfill()
        }
        let chan = pusher.subscribe("presence-channel", onMemberAdded: nil, onMemberRemoved: memberRemovedFunction) as? PusherPresenceChannel
        chan?.members.append(PusherPresenceChannelMember(userId: "100"))
        chan?.bind(eventName: "pusher:subscription_succeeded") { (event: PusherEvent) in
            let jsonDict = """
            {
                "event": "pusher_internal:member_removed",
                "channel": "presence-channel",
                "data": "{\\"user_id\\":\\"100\\"}"
            }
            """.removing(.newlines)
            self.pusher.connection.websocketDidReceiveMessage(socket: self.socket, text: jsonDict)
        }
        waitForExpectations(timeout: 0.5)
    }

    func testOnMemberRemovedFunctionGetsCalledWhenANewSubscriptionSucceedsIfTheMemberUserIdWasNotAStringOriginally() {
        let ex = expectation(description: "member removed")

        pusher.connect()

        let memberRemovedFunction = { (member: PusherPresenceChannelMember) -> Void in
            XCTAssertEqual(member.userId, "100", "the userId should be 100")
            ex.fulfill()
        }
        let chan = pusher.subscribe("presence-channel", onMemberAdded: nil, onMemberRemoved: memberRemovedFunction) as? PusherPresenceChannel
        chan?.bind(eventName: "pusher:subscription_succeeded") { (event: PusherEvent) in
            let addedJsonDict = """
            {
                "event": "pusher_internal:member_added",
                "channel": "presence-channel",
                "data": "{\\"user_id\\":100}"
            }
            """.removing(.newlines)
            self.pusher.connection.websocketDidReceiveMessage(socket: self.socket, text: addedJsonDict)

            let removedJsonDict = """
            {
                "event": "pusher_internal:member_removed",
                "channel": "presence-channel",
                "data": "{\\"user_id\\":100}"
            }
            """.removing(.newlines)
            self.pusher.connection.websocketDidReceiveMessage(socket: self.socket, text: removedJsonDict)
        }
        waitForExpectations(timeout: 0.5)
    }
}

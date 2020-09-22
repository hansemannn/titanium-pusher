import XCTest

#if WITH_ENCRYPTION
    @testable import PusherSwiftWithEncryption
#else
    @testable import PusherSwift
#endif

class PusherConnectionDelegateTests: XCTestCase {
    open class DummyDelegate: PusherDelegate {
        public let stubber = StubberForMocks()
        open var socket: MockWebSocket? = nil
        open var ex: XCTestExpectation? = nil
        var testingChannelName: String? = nil

        open func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
            let _ = stubber.stub(
                functionName: "connectionChange",
                args: [old, new],
                functionToCall: nil
            )
        }

        open func debugLog(message: String) {
            if message.range(of: "websocketDidReceiveMessage") != nil {
                self.socket?.appendToCallbackCheckString(message)
            }
        }

        open func subscribedToChannel(name: String) {
            if let cName = testingChannelName, cName == name {
                ex!.fulfill()
            }
        }

        open func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
            if let cName = testingChannelName, cName == name {
                ex!.fulfill()
            }
        }

        open func receivedError(error: PusherError) {
            let _ = stubber.stub(
                functionName: "error",
                args: [error],
                functionToCall: nil
            )
        }

    }

    var key: String!
    var pusher: Pusher!
    var socket: MockWebSocket!
    var dummyDelegate: DummyDelegate!

    override func setUp() {
        super.setUp()

        pusher = Pusher(key: "key", options: PusherClientOptions(authMethod: .inline(secret: "superSecretSecret"), autoReconnect: false))
        socket = MockWebSocket()
        socket.delegate = pusher.connection
        pusher.connection.socket = socket
        dummyDelegate = DummyDelegate()
        dummyDelegate.socket = socket
        pusher.delegate = dummyDelegate
    }

    func testConnectionStateChangeDelegateFunctionGetsCalledTwiceGoingFromDisconnectedToConnectingToConnected() {
        let ex = expectation(description: "there should be 2 calls to changedConnectionState")
        XCTAssertEqual(pusher.connection.connectionState, ConnectionState.disconnected)
        pusher.connect()
        dummyDelegate.stubber.registerCallback { calls in
            if calls.count == 2 {
                XCTAssertEqual(calls.first?.name, "connectionChange")
                XCTAssertEqual(calls.first?.args?.first as? ConnectionState, ConnectionState.disconnected)
                XCTAssertEqual(calls.first?.args?.last as? ConnectionState, ConnectionState.connecting)
                XCTAssertEqual(calls.last?.name, "connectionChange")
                XCTAssertEqual(calls.last?.args?.first as? ConnectionState, ConnectionState.connecting)
                XCTAssertEqual(calls.last?.args?.last as? ConnectionState, ConnectionState.connected)
                ex.fulfill()
            }
        }
        waitForExpectations(timeout: 0.5)
    }

    func testConnectionStateChangeDelegateFunctionGetsCalledFourTimesGoingFromDisconnectedToConnectingToConnectedToDisconnectingToDisconnected() {
        let isConnected = expectation(description: "there should be 2 calls to changedConnectionState to connected")
        let isDisconnected = expectation(description: "there should be 2 calls to changedConnectionState to disconnected")
        dummyDelegate.stubber.registerCallback { calls in
            if calls.count == 2 {
                XCTAssertEqual(calls.last?.args?.last as? ConnectionState, ConnectionState.connected)
                isConnected.fulfill()
                self.pusher.disconnect()
            }else if calls.count == 4 {
                XCTAssertEqual(calls[2].name, "connectionChange")
                XCTAssertEqual(calls[2].args?.first as? ConnectionState, ConnectionState.connected)
                XCTAssertEqual(calls[2].args?.last as? ConnectionState, ConnectionState.disconnecting)
                XCTAssertEqual(calls.last?.name, "connectionChange")
                XCTAssertEqual(calls.last?.args?.first as? ConnectionState, ConnectionState.disconnecting)
                XCTAssertEqual(calls.last?.args?.last as? ConnectionState, ConnectionState.disconnected)
                isDisconnected.fulfill()
            }
        }
        pusher.connect()
        waitForExpectations(timeout: 0.5)
    }

    func testPassingIncomingMessagesToTheDebugLogFunctionIfOneIsImplemented() {
        pusher.connect()

        XCTAssertEqual(socket.callbackCheckString, "[PUSHER DEBUG] websocketDidReceiveMessage {\"event\":\"pusher:connection_established\",\"data\":\"{\\\"socket_id\\\":\\\"45481.3166671\\\",\\\"activity_timeout\\\":120}\"}")
    }

    func testsubscriptionDidSucceedDelegateFunctionGetsCalledWhenChannelSubscriptionSucceeds() {
        let ex = expectation(description: "the subscriptionDidSucceed function should be called")
        let channelName = "private-channel"
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName

        let _ = pusher.subscribe(channelName)
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testsubscriptionDidFailDelegateFunctionGetsCalledWhenChannelSubscriptionFails() {
        let ex = expectation(description: "the subscriptionDidFail function should be called")
        let channelName = "private-channel"
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName
        pusher.connection.options.authMethod = .noMethod

        let _ = pusher.subscribe(channelName)
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testErrorFunctionCalledWhenPusherErrorIsReceived() {
        let payload = "{\"event\":\"pusher:error\", \"data\":{\"message\":\"Application is over connection quota\",\"code\":4004}}";
        pusher.connection.websocketDidReceiveMessage(socket: socket, text: payload)

        XCTAssertEqual(dummyDelegate.stubber.calls.last?.name, "error")
        guard let error = dummyDelegate.stubber.calls.last?.args?.first as? PusherError else {
            XCTFail("PusherError not returned")
            return
        }

        XCTAssertEqual(error.message, "Application is over connection quota")
        XCTAssertEqual(error.code!, 4004)
    }
}

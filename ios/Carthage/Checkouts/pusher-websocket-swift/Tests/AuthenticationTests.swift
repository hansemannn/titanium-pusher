import XCTest

#if WITH_ENCRYPTION
    @testable import PusherSwiftWithEncryption
#else
    @testable import PusherSwift
#endif

class AuthenticationTests: XCTestCase {
    class DummyDelegate: PusherDelegate {
        var ex: XCTestExpectation? = nil
        var testingChannelName: String? = nil

        func subscribedToChannel(name: String) {
            if let cName = testingChannelName, cName == name {
                ex!.fulfill()
            }
        }
    }

    var pusher: Pusher!
    var socket: MockWebSocket!

    override func setUp() {
        super.setUp()

        let options = PusherClientOptions(
            authMethod: AuthMethod.endpoint(authEndpoint: "http://localhost:9292/pusher/auth"),
            autoReconnect: false
        )
        pusher = Pusher(key: "testKey123", options: options)
        socket = MockWebSocket()
        socket.delegate = pusher.connection
        pusher.connection.socket = socket
    }

    func testSubscribingToAPrivateChannelShouldMakeARequestToTheAuthEndpoint() {
        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "private-test-channel"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName
        pusher.delegate = dummyDelegate

        if case .endpoint(authEndpoint: let authEndpoint) = pusher.connection.options.authMethod {
            let jsonData = "{\"auth\":\"testKey123:12345678gfder78ikjbg\"}".data(using: String.Encoding.utf8, allowLossyConversion: false)!
            let urlResponse = HTTPURLResponse(url: URL(string: "\(authEndpoint)?channel_name=private-test-channel&socket_id=45481.3166671")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockSession.mockResponse = (jsonData, urlResponse: urlResponse, error: nil)
            pusher.connection.URLSession = MockSession.shared
        }

        let chan = pusher.subscribe(channelName)
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testSubscribingToAPrivateChannelShouldMakeARequestToTheAuthEndpointWithAnEncodedChannelName() {
        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "private-reservations-for-venue@venue_id=399edd2d-3f4a-43k9-911c-9e4b6bdf0f16;date=2017-01-13"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName
        pusher.delegate = dummyDelegate

        if case .endpoint(authEndpoint: let authEndpoint) = pusher.connection.options.authMethod {
            let jsonData = "{\"auth\":\"testKey123:12345678gfder78ikjbg\"}".data(using: String.Encoding.utf8, allowLossyConversion: false)!
            let urlResponse = HTTPURLResponse(url: URL(string: "\(authEndpoint)?channel_name=private-reservations-for-venue%40venue_id%3D399ccd2d-3f4a-43c9-803c-9e4b6bdf0f16%3Bdate%3D2017-01-13&socket_id=45481.3166671")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockSession.mockResponse = (jsonData, urlResponse: urlResponse, error: nil)
            pusher.connection.URLSession = MockSession.shared
        }

        let chan = pusher.subscribe(channelName)
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testSubscribingToAPrivateChannelShouldCreateAuthSignatureInternally() {
        let options = PusherClientOptions(
            authMethod: .inline(secret: "secret"),
            autoReconnect: false
        )
        pusher = Pusher(key: "key", options: options)
        socket.delegate = pusher.connection
        pusher.connection.socket = socket

        let chan = pusher.subscribe("private-test-channel")
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")

        let ex = expectation(description: "subscription succeed")
        chan.bind(eventName: "pusher:subscription_succeeded") { (_: PusherEvent) in
            ex.fulfill()
            XCTAssertTrue(chan.subscribed, "the channel should be subscribed")
        }
        pusher.connect()
        waitForExpectations(timeout: 0.5)
    }

    func testSubscribingToAPrivateChannelShouldFailIfNoAuthMethodIsProvided() {
        let options = PusherClientOptions(
            autoReconnect: false
        )
        pusher = Pusher(key: "key", options: options)
        socket.delegate = pusher.connection
        pusher.connection.socket = socket

        let chan = pusher.subscribe("private-test-channel")
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
    }

    func testAuthorizationErrorsShouldLeadToAPusherSubscriptionErrorEventBeingHandled() {
        let ex = expectation(description: "subscription error callback gets called")

        if case .endpoint(authEndpoint: let authEndpoint) = pusher.connection.options.authMethod {
            let urlResponse = HTTPURLResponse(url: URL(string: "\(authEndpoint)?channel_name=private-test-channel&socket_id=45481.3166671")!, statusCode: 500, httpVersion: nil, headerFields: nil)
            MockSession.mockResponse = (nil, urlResponse: urlResponse, error: nil)
            pusher.connection.URLSession = MockSession.shared
        }

        let chan = pusher.subscribe("private-test-channel")
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")

        let _ = pusher.bind({ (data: Any?) -> Void in
            if let data = data as? [String: AnyObject], let eventName = data["event"] as? String, eventName == "pusher:subscription_error" {
                XCTAssertEqual("private-test-channel", data["channel"] as? String)
                XCTAssertTrue(Thread.isMainThread)
                ex.fulfill()
            }
        })

        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testAuthorizationUsingSomethingConformingToTheAuthRequestBuilderProtocol() {

        class AuthRequestBuilder: AuthRequestBuilderProtocol {
            func requestFor(socketID: String, channelName: String) -> URLRequest? {
                var request = URLRequest(url: URL(string: "http://localhost:9292/builder")!)
                request.httpMethod = "POST"
                request.httpBody = "socket_id=\(socketID)&channel_name=\(channelName)".data(using: String.Encoding.utf8)
                request.addValue("myToken", forHTTPHeaderField: "Authorization")
                return request
            }
        }

        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "private-test-channel"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName

        let options = PusherClientOptions(
            authMethod: AuthMethod.authRequestBuilder(authRequestBuilder: AuthRequestBuilder()),
            autoReconnect: false
        )
        pusher = Pusher(key: "testKey123", options: options)
        pusher.delegate = dummyDelegate
        socket.delegate = pusher.connection
        pusher.connection.socket = socket

        let jsonData = "{\"auth\":\"testKey123:12345678gfder78ikjbg\"}".data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let urlResponse = HTTPURLResponse(url: URL(string: "http://localhost:9292/builder?channel_name=private-test-channel&socket_id=45481.3166671")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockSession.mockResponse = (jsonData, urlResponse: urlResponse, error: nil)
        pusher.connection.URLSession = MockSession.shared

        let chan = pusher.subscribe("private-test-channel")
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testSubscribingToAPrivateChannelWhenAnAuthValueIsProvidedShouldWork() {
        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "private-manual-auth"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName
        pusher.delegate = dummyDelegate

        let chan = pusher.subscribe(channelName, auth: PusherAuth(auth: "testKey123:12345678gfder78ikjbgmanualauth"))
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testSubscribingToAPresenceChannelWhenAnAuthValueIsProvidedShouldWork() {
        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "presence-manual-auth"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName
        pusher.delegate = dummyDelegate

        let chan = pusher.subscribe(
            channelName,
            auth: PusherAuth(
                auth: "testKey123:12345678gfder78ikjbgmanualauth",
                channelData: "{\"user_id\":16,\"user_info\":{\"time\":\"2017-02-20 14:54:36 +0000\"}}"
            )
        )
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testAuthorizationUsingSomethingConformingToTheAuthorizerProtocol() {

        class SomeAuthorizer: Authorizer {
            func fetchAuthValue(socketID: String, channelName: String, completionHandler: @escaping (PusherAuth?) -> ()) {
                completionHandler(PusherAuth(auth: "testKey123:authorizerblah123"))
            }
        }

        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "private-test-channel-authorizer"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName

        let options = PusherClientOptions(
            authMethod: AuthMethod.authorizer(authorizer: SomeAuthorizer()),
            autoReconnect: false
        )
        pusher = Pusher(key: "testKey123", options: options)
        pusher.delegate = dummyDelegate
        socket.delegate = pusher.connection
        pusher.connection.socket = socket

        let chan = pusher.subscribe(channelName)
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

    func testAuthorizationOfPresenceChannelSubscriptionUsingSomethingConformingToTheAuthorizerProtocol() {

        class SomeAuthorizer: Authorizer {
            func fetchAuthValue(socketID: String, channelName: String, completionHandler: @escaping (PusherAuth?) -> ()) {
                completionHandler(PusherAuth(
                    auth: "testKey123:authorizerblah1234",
                    channelData: "{\"user_id\":\"777\", \"user_info\":{\"twitter\":\"hamchapman\"}}"
                ))
            }
        }

        let ex = expectation(description: "the channel should be subscribed to successfully")
        let channelName = "presence-test-channel-authorizer"

        let dummyDelegate = DummyDelegate()
        dummyDelegate.ex = ex
        dummyDelegate.testingChannelName = channelName

        let options = PusherClientOptions(
            authMethod: AuthMethod.authorizer(authorizer: SomeAuthorizer()),
            autoReconnect: false
        )
        pusher = Pusher(key: "testKey123", options: options)
        pusher.delegate = dummyDelegate
        socket.delegate = pusher.connection
        pusher.connection.socket = socket

        let chan = pusher.subscribe(channelName)
        XCTAssertFalse(chan.subscribed, "the channel should not be subscribed")
        pusher.connect()

        waitForExpectations(timeout: 0.5)
    }

}

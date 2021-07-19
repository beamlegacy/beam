//
//  BrowsingTreeSenderTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 01/07/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

class MockUploadTask: URLSessionUploadTaskProtocol {
    private let closure: () -> Void
    init(closure: @escaping () -> Void) {
            self.closure = closure
        }
    func resume() { closure() }
}
class MockURLSession: URLSessionProtocol {
    private (set) var lastPayload: Data?
    var response: HTTPURLResponse?
    var error: Error?
    public var taskCallCount: Int = 0

    func mockableUploadTask(with: URLRequest, from: Data?, completionHandler: @escaping DataTaskResult) -> URLSessionUploadTaskProtocol {
        taskCallCount += 1
        lastPayload = from
        return MockUploadTask { [self] in completionHandler(nil, self.response, self.error) }
    }
}

class BrowsingTreeSenderTest: XCTestCase {

    var subject: BrowsingTreeSender!
    var session: MockURLSession!

    override func setUpWithError() throws {
        super.setUp()
        Configuration.browsingSessionCollectionIsOn = true
        session = MockURLSession()
        let testConfig = BrowsingTreeSenderConfig(
            dataStoreUrl: "http://url.fr",
            dataStoreApiToken: "abc"
        )
        subject = BrowsingTreeSender(session: session, config: testConfig)
    }
    override func tearDownWithError() throws {
        Configuration.browsingSessionCollectionIsOn = true
    }

    func testSentData() throws {
        func sentData(session: MockURLSession) throws  -> BrowsingTreeSendData {
            let payload = try XCTUnwrap(session.lastPayload, "session uploadTask shoud have been called")
            let sentData = try? decoder.decode(BrowsingTreeSendData.self, from: payload)
            return try XCTUnwrap(sentData, "sent data should decode")
        }

        let decoder = JSONDecoder()
        let tree = BrowsingTree(nil)
        subject.send(browsingTree: tree)
        let unwrappedData = try sentData(session: session)

        XCTAssertEqual(unwrappedData.rootCreatedAt, tree.root.events.first!.date.timeIntervalSince1970)
        XCTAssertEqual(unwrappedData.rootId, tree.root.id)
        XCTAssertEqual(unwrappedData.data.root.id, tree.root.id)
        XCTAssertEqual(unwrappedData.data.current.id, tree.current.id)

        let anotherTree = BrowsingTree(nil)
        subject.send(browsingTree: anotherTree)
        let otherUnwrappedData = try sentData(session: session)

        XCTAssertEqual(otherUnwrappedData.rootCreatedAt, anotherTree.root.events.first!.date.timeIntervalSince1970)
        XCTAssertEqual(otherUnwrappedData.rootId, anotherTree.root.id)
        XCTAssertEqual(otherUnwrappedData.data.root.id, anotherTree.root.id)
        XCTAssertEqual(otherUnwrappedData.data.current.id, anotherTree.current.id)
        XCTAssertEqual(unwrappedData.userId, otherUnwrappedData.userId)
    }

    func testCompletionCallOnError() throws {
        struct MyError: Error {}
        let tree = BrowsingTree(nil)
        var completionCalled = false
        session.error = MyError()
        subject.send(browsingTree: tree) {completionCalled = true}
        XCTAssert(completionCalled)
    }

    func testCompletionCallOnServerError() throws {
        let tree = BrowsingTree(nil)
        var completionCalled = false
        session.response = HTTPURLResponse(url: URL(string: "http://url.fr")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        subject.send(browsingTree: tree) {completionCalled = true}
        XCTAssert(completionCalled)
    }

    func testCompletionCallOnSuccess() throws {
        let tree = BrowsingTree(nil)
        var completionCalled = false
        session.response = HTTPURLResponse(url: URL(string: "http://url.fr")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        subject.send(browsingTree: tree) {completionCalled = true}
        XCTAssert(completionCalled)
    }

    func testDisabledByConfiguration() throws {
        let tree = BrowsingTree(nil)
        Configuration.browsingSessionCollectionIsOn = false
        subject.send(browsingTree: tree)
        XCTAssertEqual(session.taskCallCount, 0)
        Configuration.browsingSessionCollectionIsOn = true
        subject.send(browsingTree: tree)
        XCTAssertEqual(session.taskCallCount, 1)
        Configuration.browsingSessionCollectionIsOn = false
        subject.send(browsingTree: tree)
        XCTAssertEqual(session.taskCallCount, 1)
    }
    
    func testFaultyConfig() throws {
        let missingUrlConfig = BrowsingTreeSenderConfig(
            dataStoreUrl: "$(BROWSING_TREE_URL)",
            dataStoreApiToken: "abc"
        )
        var sender = BrowsingTreeSender(session: session, config: missingUrlConfig)
        XCTAssertNil(sender)

        let missingTokenConfig = BrowsingTreeSenderConfig(
            dataStoreUrl: "http://url.fr",
            dataStoreApiToken: "$(BROWSING_TREE_ACCESS_TOKEN)"
        )
        sender = BrowsingTreeSender(session: session, config: missingTokenConfig)
        XCTAssertNil(sender)
    }
}

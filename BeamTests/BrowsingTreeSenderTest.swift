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

    func mockableUploadTask(with: URLRequest, from: Data?, completionHandler: @escaping DataTaskResult) -> URLSessionUploadTaskProtocol {
        lastPayload = from
        return MockUploadTask { [self] in completionHandler(nil, self.response, self.error) }
    }
}

class BrowsingTreeSenderTest: XCTestCase {

    var subject: BrowsingTreeSender!
    var session: MockURLSession!

    override func setUpWithError() throws {
        super.setUp()
        session = MockURLSession()
        subject = BrowsingTreeSender(session: session, testDataStoreUrl: "www.abc.com")
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
        session.response = HTTPURLResponse(url: URL(string: "www.abc.com")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        subject.send(browsingTree: tree) {completionCalled = true}
        XCTAssert(completionCalled)
    }
    
    func testCompletionCallOnSuccess() throws {
        let tree = BrowsingTree(nil)
        var completionCalled = false
        session.response = HTTPURLResponse(url: URL(string: "www.abc.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        subject.send(browsingTree: tree) {completionCalled = true}
        XCTAssert(completionCalled)
    }

}

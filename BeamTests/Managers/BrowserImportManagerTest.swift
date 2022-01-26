//
//  BrowserImportManagerTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 16/12/2021.
//

import XCTest
import Nimble
import Combine
@testable import BeamCore
@testable import Beam

class BrowserImportManagerTest: XCTestCase {
    struct FakeHistoryItem: BrowserHistoryItem {
        var timestamp: Date
        var title: String?
        var url: URL?
        
        init(secondsFromReference: Double, title: String?, urlString: String) {
            self.timestamp = Date(timeIntervalSinceReferenceDate: Double(secondsFromReference))
            self.title = title
            self.url = URL(string: urlString)
        }
    }

    class FakeImporter: BrowserHistoryImporter {
        private var items: [BrowserHistoryItem?] = [
            FakeHistoryItem(secondsFromReference: 1, title: "abc", urlString: "http://abc.com"),
            FakeHistoryItem(secondsFromReference: 0, title: "def", urlString: "http://def.com"),
        ]

        var sourceBrowser: BrowserType = .firefox
                
        func historyDatabaseURL() throws -> URL? {
            URL(string: "/myDbUrl")
        }
        var currentSubject: PassthroughSubject<BrowserHistoryResult, Error>?

        var publisher: AnyPublisher<BrowserHistoryResult, Error> {
            let subject = currentSubject ?? PassthroughSubject<BrowserHistoryResult, Error>()
            currentSubject = subject
            return subject.eraseToAnyPublisher()
        }
        func importHistory(from databaseURL: URL) throws {
            let itemCount = items.count
            while let popedItem = items.popLast() {
                if let item = popedItem {
                    currentSubject?.send(BrowserHistoryResult(itemCount: itemCount, item: item))
                }
            }
            currentSubject?.send(completion: .finished)
        }
        func importHistory(from dbPath: String) throws {}

    }

    override func setUpWithError() throws {
        try BrowsingTreeStoreManager.shared.clearBrowsingTrees()
        try LinkStore.shared.deleteAll()
        try GRDBDatabase.shared.clearUrlFrecencies()
    }

    override func tearDownWithError() throws {
        try BrowsingTreeStoreManager.shared.clearBrowsingTrees()
        try LinkStore.shared.deleteAll()
        try GRDBDatabase.shared.clearUrlFrecencies()
    }

    func testImport() throws {
        let manager = ImportsManager()
        manager.startBrowserHistoryImport(from: FakeImporter())
        //wait for import completion
        expect(manager.isImporting).toEventually(beFalse())
        //expects one tree to be saved
        XCTAssertEqual(BrowsingTreeStoreManager.shared.countBrowsingTrees, 1)
        let treeRecord = try BrowsingTreeStoreManager.shared.allObjects(updatedSince: nil)[0]
        let flattenedData = try XCTUnwrap(treeRecord.flattenedData)
        //with right tree origin
        let tree = try XCTUnwrap(BrowsingTree(flattenedTree: flattenedData))
        XCTAssertEqual(tree.origin, .historyImport(sourceBrowser: .firefox))
        let root = tree.root
        let node0 = try XCTUnwrap(root?.children[0])
        let node1 = try XCTUnwrap(root?.children[1])
        XCTAssertEqual(node0.events.first?.date, Date(timeIntervalSinceReferenceDate: Double(0)))
        XCTAssertEqual(node1.events.first?.date, Date(timeIntervalSinceReferenceDate: Double(1)))
        let links = [node0.link, node1.link]
        //expects 2 frecencies to be saved
        let frecencies = GRDBDatabase.shared.getFrecencyScoreValues(urlIds: links, paramKey: .webVisit30d0)
        XCTAssertEqual(frecencies.count, 2)
    }
}

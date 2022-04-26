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
        let itemLimit: Int = 0
        let itemCount: Int
        var currentSubject: PassthroughSubject<BrowserHistoryResult, Error>?
        var startDate: Date?

        init(itemCount: Int) {
            self.itemCount = itemCount
        }

        var publisher: AnyPublisher<BrowserHistoryResult, Error> {
            let subject = currentSubject ?? PassthroughSubject<BrowserHistoryResult, Error>()
            currentSubject = subject
            return subject.eraseToAnyPublisher()
        }

        func historyDatabaseURL() throws -> URLProvider? {
            URL(string: "/myDbUrl")
        }

        var sourceBrowser: BrowserType = .firefox
        func importHistory(from databaseURL: URL, startDate: Date? = nil) throws {
            self.startDate = startDate
            for i in 0..<itemCount {
                let item = FakeHistoryItem(secondsFromReference: Double(i), title: nil, urlString: "http://www.site.com/\(i)")
                currentSubject?.send(BrowserHistoryResult(itemCount: itemCount, item: item))
            }
            currentSubject?.send(completion: .finished)
        }
        func importHistory(from dbPath: String, startDate: Date? = nil) throws {}
    }

    override func setUpWithError() throws {
        try BrowsingTreeStoreManager.shared.clearBrowsingTrees()
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try GRDBDatabase.shared.clearUrlFrecencies()
        Persistence.cleanUp()
    }

    override func tearDownWithError() throws {
        try BrowsingTreeStoreManager.shared.clearBrowsingTrees()
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try GRDBDatabase.shared.clearUrlFrecencies()
        Persistence.cleanUp()
    }

    func testImport() throws {
        let manager = ImportsManager()
        var importer = FakeImporter(itemCount: 2)
        XCTAssertEqual(LinkStore.shared.allLinks.count, 0)
        manager.startBrowserHistoryImport(from: importer)
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
        let node1 = try XCTUnwrap(node0.children[0])
        XCTAssertEqual(node0.events.first?.date, Date(timeIntervalSinceReferenceDate: Double(0)))
        XCTAssertEqual(node1.events.first?.date, Date(timeIntervalSinceReferenceDate: Double(1)))
        let urlIds = [node0.link, node1.link]
        //expects 2 frecencies to be saved in linkstore and not in frecencyRecord table anymore
        let frecencies = GRDBDatabase.shared.getFrecencyScoreValues(urlIds: urlIds, paramKey: .webVisit30d0)
        XCTAssertEqual(frecencies.count, 0)
        let links: [UUID: Link] = try GRDBDatabase.shared.getLinks(ids: urlIds)
        XCTAssertNotNil(links[node0.link]?.frecencyVisitScore)
        XCTAssertNotNil(links[node0.link]?.frecencyVisitSortScore)
        XCTAssertNotNil(links[node0.link]?.frecencyVisitLastAccessAt)
        XCTAssertNotNil(links[node1.link]?.frecencyVisitScore)
        XCTAssertNotNil(links[node1.link]?.frecencyVisitSortScore)
        XCTAssertNotNil(links[node1.link]?.frecencyVisitLastAccessAt)
        //max imported date is stored for the right browser
        XCTAssertNil(importer.startDate)
        let maxDate = try XCTUnwrap(Persistence.ImportedBrowserHistory.getMaxDate(for:.firefox))
        XCTAssertNil(Persistence.ImportedBrowserHistory.getMaxDate(for:.chrome))
        XCTAssertEqual(maxDate, Date(timeIntervalSinceReferenceDate: Double(1)))
        //and is used in subsequent call
        importer = FakeImporter(itemCount: 2)
        manager.startBrowserHistoryImport(from: importer)
        expect(manager.isImporting).toEventually(beFalse())
        XCTAssertEqual(importer.startDate, maxDate)
    }

    func testBatchImporter() throws {
        let batchImporter = BatchHistoryImporter(sourceBrowser: .firefox, batchSize: 2)
        for i in 0..<3 {
            batchImporter.add(item: FakeHistoryItem(secondsFromReference: Double(i), title: nil, urlString: "http://www.site.com/\(i)"))
        }
        batchImporter.finalize {}
        //expects one tree to be saved
        XCTAssertEqual(BrowsingTreeStoreManager.shared.countBrowsingTrees, 1)
        let treeRecord = try BrowsingTreeStoreManager.shared.allObjects(updatedSince: nil)[0]
        let flattenedData = try XCTUnwrap(treeRecord.flattenedData)
        //with right tree origin
        let tree = try XCTUnwrap(BrowsingTree(flattenedTree: flattenedData))
        XCTAssertEqual(tree.origin, .historyImport(sourceBrowser: .firefox))
        let root = tree.root
        let node0 = try XCTUnwrap(root?.children[0])
        let node1 = try XCTUnwrap(node0.children[0])
        let node2 = try XCTUnwrap(node1.children[0]) //checks that last node has not been forgotten by batch mechanics
        let nodes = [node0, node1, node2]

        for i in 0..<3 {
            XCTAssertEqual(nodes[i].events.first?.date, Date(timeIntervalSinceReferenceDate: Double(i)))
        }
        let urlIds = nodes.map { $0.link }
        //expects 3 frecencies to be saved in linkstore and not in frecencyRecord table anymore
        let frecencies = GRDBDatabase.shared.getFrecencyScoreValues(urlIds: urlIds, paramKey: .webVisit30d0)
        XCTAssertEqual(frecencies.count, 0)
        let links: [UUID: Link] = try GRDBDatabase.shared.getLinks(ids: urlIds)
        for node in nodes {
            XCTAssertNotNil(links[node.link]?.frecencyVisitScore)
            XCTAssertNotNil(links[node.link]?.frecencyVisitSortScore)
            XCTAssertNotNil(links[node.link]?.frecencyVisitLastAccessAt)
        }
    }

    func testSpeed() throws {
        let manager = ImportsManager()
        let importer = FakeImporter(itemCount: 10_000)
        let timeout = DispatchTimeInterval.seconds(10 * 60)
        let pollInterval = DispatchTimeInterval.seconds(1)
        manager.startBrowserHistoryImport(from: importer)
        //wait for import completion
        expect(manager.isImporting).toEventually(beFalse(), timeout: timeout, pollInterval: pollInterval)
    }
}

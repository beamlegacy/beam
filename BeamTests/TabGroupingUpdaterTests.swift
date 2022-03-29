import Quick
import Nimble
import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class TabGroupingUpdaterTests: XCTestCase {
    private var updater: TabGroupingUpdater!
    private var urlGroups: [[ClusteringManager.PageID]]!
    private var openPages: [ClusteringManager.PageID]!
    private var pageIDs: [ClusteringManager.PageID] = []

    override func setUp() {
        updater = TabGroupingUpdater()
        for _ in 0...6 {
            pageIDs.append(UUID())
        }
        urlGroups = [
            [pageIDs[0]],
            [pageIDs[1]],
            [pageIDs[2]],
            [pageIDs[3], pageIDs[4], pageIDs[5], pageIDs[6]]
        ]
        openPages = [pageIDs[0], pageIDs[1], pageIDs[2],
                     pageIDs[4], pageIDs[5]
        ]
    }

    func testRemoveClosedPages() throws {
        let newUrlGroups = updater.removeClosedPages(urlGroups: self.urlGroups, openPages: self.openPages)
        expect(newUrlGroups) == [[pageIDs[0]], [pageIDs[1]], [pageIDs[2]], [pageIDs[4], pageIDs[5]]]
    }

    func testRemoveSingles() throws {
        let newUrlGroups = updater.removeSingles(urlGroups: self.urlGroups)
        expect(Set(newUrlGroups)) == Set([[pageIDs[3], pageIDs[4], pageIDs[5], pageIDs[6]]])
    }

    func testAll() throws {
        updater.update(urlGroups: urlGroups, openPages: openPages)
        expect(self.updater.builtPagesGroups.values.count).toEventually(equal(2))
        let groups = updater.builtPagesGroups
        expect(groups.values.first?.pageIDs ?? []) == [pageIDs[4], pageIDs[5]]
    }

    func testAllWithoutOpenPages() throws {
        updater.update(urlGroups: urlGroups)
        expect(self.updater.builtPagesGroups.values.count).toEventually(equal(7))
        let results = updater.builtPagesGroups
        for group in urlGroups {
            for page in group {
                expect(results[page]?.pageIDs ?? []) == group
            }
        }
    }
}

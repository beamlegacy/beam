import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class TabGroupingManagerOpenPagesTests: XCTestCase {
    private var updater: TabGroupingManager!
    private var urlGroups: [[ClusteringManager.PageID]]!
    private var openPages: [ClusteringManager.PageID]!
    private var pageIDs: [ClusteringManager.PageID] = []

    override func setUp() {
        updater = TabGroupingManager()
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
        XCTAssertEqual(Set(newUrlGroups), Set([[pageIDs[0]], [pageIDs[1]], [pageIDs[2]], [pageIDs[4], pageIDs[5]]]))
    }

    func testRemoveSingles() throws {
        let newUrlGroups = updater.removeSingles(urlGroups: self.urlGroups)
        XCTAssertEqual(Set(newUrlGroups), Set([[pageIDs[3], pageIDs[4], pageIDs[5], pageIDs[6]]]))
    }

    func testAllWithOpenPages() async throws {
        await updater.updateAutomaticClustering(urlGroups: urlGroups, openPages: openPages)
        XCTAssertEqual(updater.builtPagesGroups.values.count, 2)
        let groups = updater.builtPagesGroups
        XCTAssertEqual(Set(groups.values.first?.pageIds ?? []), Set([pageIDs[4], pageIDs[5]]))
    }

    func testAllWithoutOpenPages() async throws {
        await updater.updateAutomaticClustering(urlGroups: urlGroups)
        XCTAssertEqual(updater.builtPagesGroups.values.count, 7)
        let results = updater.builtPagesGroups
        for group in urlGroups {
            for page in group {
                let pageIds = results[page]?.pageIds ?? []
                XCTAssertEqual(pageIds.count, group.count)
                XCTAssertEqual(Set(pageIds), Set(group))
            }
        }
    }
}

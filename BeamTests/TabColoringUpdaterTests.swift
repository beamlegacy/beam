import Quick
import Nimble
import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class TabColoringUpdaterTests: XCTestCase {
    private var updater: TabColoringUpdater!
    private var urlGroups: [[UUID]]!
    private var openPages: [ClusteringManager.PageOpenInTab]!
    private var pageIDs: [UUID] = []

    override func setUp() {
        updater = TabColoringUpdater()
        for _ in 0...6 {
            pageIDs.append(UUID())
        }
        urlGroups = [[pageIDs[0]], [pageIDs[1]], [pageIDs[2]], [pageIDs[3], pageIDs[4], pageIDs[5], pageIDs[6]]]
        openPages = [ClusteringManager.PageOpenInTab(pageId: pageIDs[0]), ClusteringManager.PageOpenInTab(pageId: pageIDs[1]), ClusteringManager.PageOpenInTab(pageId: pageIDs[2]), ClusteringManager.PageOpenInTab(pageId: pageIDs[4]), ClusteringManager.PageOpenInTab(pageId: pageIDs[5])]
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
        expect(Set(self.updater.groupsToColor ?? [])).toEventually(equal(Set([[pageIDs[4], pageIDs[5]]])))
    }

    func testAllWithoutOpenPages() throws {
        updater.update(urlGroups: urlGroups)
        expect(self.updater.groupsToColor).toEventually(equal(urlGroups))
    }
}

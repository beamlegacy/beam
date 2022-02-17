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
        openPages = [ClusteringManager.PageOpenInTab(pageId: pageIDs[0], domain: "www.theguardian.com"), ClusteringManager.PageOpenInTab(pageId: pageIDs[1], domain: "www.theguardian.com"), ClusteringManager.PageOpenInTab(pageId: pageIDs[2], domain: "www.theguardian.com"), ClusteringManager.PageOpenInTab(pageId: pageIDs[4], domain: "en.wikipedia.org"), ClusteringManager.PageOpenInTab(pageId: pageIDs[5], domain: "www.rogerfederer.com")]
    }

    func testRemoveClosedPages() throws {
        let newUrlGroups = updater.removeClosedPages(urlGroups: self.urlGroups, openPages: self.openPages)
        expect(newUrlGroups) == [[pageIDs[0]], [pageIDs[1]], [pageIDs[2]], [pageIDs[4], pageIDs[5]]]
    }

    func testMergeSinglesOfSameDomain() throws {
        var newUrlGroups = updater.removeClosedPages(urlGroups: self.urlGroups, openPages: self.openPages)
        newUrlGroups = updater.mergeSinglesOfSameDomain(urlGroups: newUrlGroups, allOpenPages: self.openPages)
        expect(Set(newUrlGroups)) == Set([[pageIDs[0], pageIDs[1], pageIDs[2]], [pageIDs[4], pageIDs[5]]])
    }

    func testMergeSingleWithGroupOfSameDomain() throws {
        urlGroups = [[pageIDs[0], pageIDs[1]], [pageIDs[2]], [pageIDs[3], pageIDs[4], pageIDs[5], pageIDs[6]]]
        var newUrlGroups = updater.removeClosedPages(urlGroups: self.urlGroups, openPages: self.openPages)
        newUrlGroups = updater.mergeSinglesOfSameDomain(urlGroups: newUrlGroups, allOpenPages: self.openPages)
        newUrlGroups = updater.mergeSingleWithGroupOfSameDomain(urlGroups: newUrlGroups, allOpenPages: self.openPages)
        expect(Set(newUrlGroups)) == Set([[pageIDs[0], pageIDs[1], pageIDs[2]], [pageIDs[4], pageIDs[5]]])
    }

    func testAll() throws {
        updater.update(urlGroups: urlGroups, openPages: openPages)
        expect(Set(self.updater.groupsToColor ?? [])).toEventually(equal(Set([[pageIDs[0], pageIDs[1], pageIDs[2]], [pageIDs[4], pageIDs[5]]])))
    }

    func testAllWithoutOpenPages() throws {
        updater.update(urlGroups: urlGroups)
        expect(self.updater.groupsToColor).toEventually(equal(urlGroups))
    }
}

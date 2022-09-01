import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class TabGroupingManagerURLGroupsManipulationsTests: XCTestCase {
    private var sut = TabGroupingManager()
    private var urlGroups: [[ClusteringManager.PageID]] = []
    private var openPages: [ClusteringManager.PageID] = []
    private var openTabs: [BrowserTab] = []
    private var pageIDs: [ClusteringManager.PageID] = []
    private var producesSingleGroupWithAllPages: Bool {
        sut.clusteringManager?.typeInUse.producesSingleGroupWithAllPages == true
    }

    override func setUp() {
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
        openTabs = openPages.map { tab(withPageId: $0) }
    }

    // Each tests that uses automatic clustering (updateAutomaticClustering called)
    // should be perfomed with both clustering types
    func setUpWithClusteringType(_ type: ClusteringType) {
        sut.clusteringManager?.changeClusteringType(type)
        XCTAssertEqual(sut.clusteringManager?.typeInUse, type)
    }

    private func tab(withPageId pageId: UUID) -> BrowserTab {
        let tab = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .web, note: nil)
        tab.browsingTree.current.link = pageId
        return tab
    }


    // MARK: -
    func testRemoveClosedPages_legacy() {
        setUpWithClusteringType(.legacy)
        _testRemoveClosedPages()
    }
    func testRemoveClosedPages_smart() {
        setUpWithClusteringType(.smart)
        _testRemoveClosedPages()
    }
    func _testRemoveClosedPages() {
        let newUrlGroups = sut.removeClosedPages(urlGroups: self.urlGroups, openPages: self.openPages)
        XCTAssertEqual(Set(newUrlGroups), Set([[pageIDs[0]], [pageIDs[1]], [pageIDs[2]], [pageIDs[4], pageIDs[5]]]))
    }

    // MARK: -
    func testRemoveSingles_legacy() {
        setUpWithClusteringType(.legacy)
        _testRemoveSingles()
    }
    func testRemoveSingles_smart() {
        setUpWithClusteringType(.smart)
        _testRemoveSingles()
    }
    func _testRemoveSingles() {
        let newUrlGroups = sut.removeSingles(urlGroups: self.urlGroups, openTabs: self.openTabs)
        XCTAssertEqual(Set(newUrlGroups), Set([[pageIDs[3], pageIDs[4], pageIDs[5], pageIDs[6]]]))
    }

    // MARK: -
    func testRemoveSinglesKeepSingleGroupWhenMultipleTabs_legacy() {
        setUpWithClusteringType(.legacy)
        _testRemoveSingles()
    }
    func testRemoveSinglesKeepSingleGroupWhenMultipleTabs_smart() {
        setUpWithClusteringType(.smart)
        _testRemoveSinglesKeepSingleGroupWhenMultipleTabs()
    }
    func _testRemoveSinglesKeepSingleGroupWhenMultipleTabs() {
        // page0 is opened multiple times, so it's a group
        self.openTabs = [ tab(withPageId: pageIDs[0]), tab(withPageId: pageIDs[0]), tab(withPageId: pageIDs[1]) ]
        var newUrlGroups = sut.removeSingles(urlGroups: [ [pageIDs[0]], [pageIDs[1]] ], openTabs: self.openTabs)
        XCTAssertEqual(Set(newUrlGroups), Set([ [pageIDs[0]] ]))

        // even if we have one big group with all pages
        newUrlGroups = sut.removeSingles(urlGroups: [ [pageIDs[0], pageIDs[1], pageIDs[2]] ], openTabs: self.openTabs)
        if producesSingleGroupWithAllPages {
            // 1 single group of all tabs was converted into 3 small groups of 1 tab, and then filtered out.
            XCTAssertEqual(Set(newUrlGroups), Set([ [pageIDs[0]] ]))
        } else {
            XCTAssertEqual(Set(newUrlGroups), Set( [[pageIDs[0], pageIDs[1], pageIDs[2]]])) 
        }
    }

    // MARK: -
    func testAllWithOpenPages_legacy() async {
        setUpWithClusteringType(.legacy)
        await _testAllWithOpenPages()
    }
    func testAllWithOpenPages_smart() async {
        setUpWithClusteringType(.smart)
        await _testAllWithOpenPages()
    }
    func _testAllWithOpenPages() async {
        await sut.updateAutomaticClustering(urlGroups: urlGroups, openPages: openPages)
        XCTAssertEqual(sut.builtPagesGroups.values.count, 2)

        let groups = sut.builtPagesGroups
        XCTAssertEqual(Set(groups.values.first?.pageIds ?? []), Set([pageIDs[4], pageIDs[5]]))
    }

    // MARK: -
    func testAllWithoutOpenPages_legacy() async {
        setUpWithClusteringType(.legacy)
        await _testAllWithoutOpenPages()
    }
    func testAllWithoutOpenPages_smart() async {
        setUpWithClusteringType(.smart)
        await _testAllWithoutOpenPages()
    }
    func _testAllWithoutOpenPages() async {
        await sut.updateAutomaticClustering(urlGroups: urlGroups)
        XCTAssertEqual(sut.builtPagesGroups.values.count, 7)
        let results = sut.builtPagesGroups
        for group in urlGroups {
            for page in group {
                let pageIds = results[page]?.pageIds ?? []
                XCTAssertEqual(pageIds.count, group.count)
                XCTAssertEqual(Set(pageIds), Set(group))
            }
        }
    }
}

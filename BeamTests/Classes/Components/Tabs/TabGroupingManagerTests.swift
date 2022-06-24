//
//  TabGroupingManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 17/06/2022.
//

import XCTest
@testable import Beam

class TabGroupingManagerTests: XCTestCase {

    var sut: TabGroupingManager = TabGroupingManager()
    let state = BeamState()

    private var clusters = [[ClusteringManager.PageID]]()
    private var openPages = [ClusteringManager.PageID]()
    private var pageIds = [ClusteringManager.PageID]()
    private var manualGroups = [TabGroup]()
    private var tabGroupingDelegate = TestTabGroupingDelegate()
    class TestTabGroupingDelegate: TabGroupingManagerDelegate {
        fileprivate var tabs: [BrowserTab] = []
        func allOpenTabsForTabGroupingManager(_ tabGroupingManager: TabGroupingManager) -> [BrowserTab] {
            tabs
        }
    }

    override func setUp() {
        sut.delegate = tabGroupingDelegate
    }

    func setupDefaultOpenPages() {
        for _ in 0...6 {
            pageIds.append(UUID())
        }
        openPages = [ pageIds[0], pageIds[1], pageIds[4], pageIds[5], pageIds[6] ]
    }

    func setupClusters() {
        clusters = [
            [pageIds[0]],
            [pageIds[1]],
            [pageIds[2]],
            [pageIds[3], pageIds[4], pageIds[5], pageIds[6]]
        ]
    }

    @MainActor
    func tab(withPageId pageId: UUID) async -> BrowserTab {
        let tab = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .web, note: nil)
        tab.browsingTree.current.link = pageId
        return tab
    }

    @MainActor
    func setupManualGroup() async {
        let group = TabGroup(pageIds: [], title: "ManualGroup")
        manualGroups.append(group)

        for pageId in [pageIds[0], pageIds[1]] {
            let tab = await tab(withPageId: pageId)
            tabGroupingDelegate.tabs.append(tab)
            sut.moveTab(tab, inGroup: group)
        }
    }

    func testBuildTabGroupsWith1Cluster() async {
        setupDefaultOpenPages()
        setupClusters()
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(sut.builtPagesGroups.count, 3)
        XCTAssertEqual(sut.builtPagesGroups[pageIds[4]], sut.builtPagesGroups[pageIds[6]])
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 1) // only one group was created
        let group = sut.builtPagesGroups[pageIds[4]]
        XCTAssertEqual(group?.pageIds.count, 3) // pageIds[3] is not opened
        XCTAssertEqual(group?.pageIds.contains(pageIds[4]), true)
        XCTAssertEqual(group?.pageIds.contains(pageIds[5]), true)
        XCTAssertEqual(group?.pageIds.contains(pageIds[6]), true)
    }

    func testBuildTabGroupsWith1ClusterIsReused() async {
        setupDefaultOpenPages()
        setupClusters()
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 1) // only one group was created
        let group = sut.builtPagesGroups.values.first
        XCTAssertEqual(group?.pageIds.count, 3) // pageIds[3] is not opened
        group?.changeTitle("Renamed Group")

        // redo a clustering update
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 1)
        XCTAssertEqual(sut.builtPagesGroups.values.first, group) // group is still the same
        XCTAssertEqual(sut.builtPagesGroups.values.first?.title, "Renamed Group")
    }

    func testBuildTabGroupsWith1ManualGroup1Cluster() async {
        setupDefaultOpenPages()
        setupClusters()
        await setupManualGroup()
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 2)
        XCTAssertEqual(sut.builtPagesGroups.count, 5)

        let manualGRoup = sut.builtPagesGroups[pageIds[0]]
        XCTAssertEqual(manualGRoup?.pageIds.count, 2)
        XCTAssertEqual(manualGRoup?.title, "ManualGroup")
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[0]), true)
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[1]), true)

        XCTAssertEqual(sut.builtPagesGroups[pageIds[4]], sut.builtPagesGroups[pageIds[6]])
        let automaticCroup = sut.builtPagesGroups[pageIds[4]]
        XCTAssertEqual(automaticCroup?.pageIds.count, 3) // pageIds[3] is not opened
        XCTAssertNil(automaticCroup?.title)
        XCTAssertEqual(automaticCroup?.pageIds.contains(pageIds[4]), true)
        XCTAssertEqual(automaticCroup?.pageIds.contains(pageIds[5]), true)
        XCTAssertEqual(automaticCroup?.pageIds.contains(pageIds[6]), true)
    }

    func testBuildTabGroupsMoveWholeClusterToManualGroup() async {
        setupDefaultOpenPages()
        await setupManualGroup()
        clusters = [
            [pageIds[0]],
            [pageIds[1], pageIds[4], pageIds[5], pageIds[6]]
        ]
        // page0 and page1 are manually grouped, so the other pages in the clusters will be attached

        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 1)
        XCTAssertEqual(sut.builtPagesGroups.count, 5)

        let manualGRoup = sut.builtPagesGroups[pageIds[0]]
        XCTAssertEqual(manualGRoup?.pageIds.count, 5)
        XCTAssertEqual(manualGRoup?.title, "ManualGroup")
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[0]), true)
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[1]), true)
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[4]), true)
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[5]), true)
        XCTAssertEqual(manualGRoup?.pageIds.contains(pageIds[6]), true)
    }

    func testForcedOutOfGroup() async {
        setupDefaultOpenPages()
        clusters = [
            [pageIds[0], pageIds[1]],
            [pageIds[4], pageIds[5], pageIds[6]]
        ]
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 2)
        XCTAssertEqual(sut.builtPagesGroups.count, 5)

        let page4Group = sut.builtPagesGroups[pageIds[4]]
        let tab4 = await tab(withPageId: pageIds[4])
        tabGroupingDelegate.tabs = [tab4]

        sut.moveTab(tab4, inGroup: nil, outOfGroup: page4Group)

        // page groups should be updated
        XCTAssertEqual(sut.builtPagesGroups.count, 4)
        XCTAssertNil(sut.builtPagesGroups[pageIds[4]])

        // updating the clustering should prevent it from being grouped again
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(sut.builtPagesGroups.count, 4)
        XCTAssertNil(sut.builtPagesGroups[pageIds[4]])

        // Clearing assignment should bring back clustering suggestions
        sut.moveTab(tab4, inGroup: nil, outOfGroup: nil)
        XCTAssertEqual(sut.builtPagesGroups.count, 4)
        XCTAssertNil(sut.builtPagesGroups[pageIds[4]])
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 2)
        XCTAssertEqual(sut.builtPagesGroups.count, 5)
        XCTAssertEqual(sut.builtPagesGroups[pageIds[4]], page4Group)

        // Assigning to group 1
        let page1Group = sut.builtPagesGroups[pageIds[1]]
        sut.moveTab(tab4, inGroup: page1Group, outOfGroup: nil)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 2)
        XCTAssertEqual(sut.builtPagesGroups.count, 5)
        XCTAssertEqual(sut.builtPagesGroups[pageIds[4]], page1Group)
        await sut.updateAutomaticClustering(urlGroups: clusters, openPages: openPages)
        XCTAssertEqual(Set(sut.builtPagesGroups.values).count, 1) // all tabs have been moved to the main group
        XCTAssertEqual(sut.builtPagesGroups.count, 5)
        XCTAssertEqual(sut.builtPagesGroups[pageIds[4]], page1Group)
    }

}

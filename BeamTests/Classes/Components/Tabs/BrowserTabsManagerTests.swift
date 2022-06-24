//
//  BrowserTabsManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 19/05/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class BrowserTabsManagerTests: XCTestCase {

    lazy var state = BeamState()
    var sut: BrowserTabsManager!

    override func setUp() {
        sut = BrowserTabsManager(with: state.data, state: state)
    }

    override func tearDown() {
        state.data.savePinnedTabs([])
    }

    private func tab(_ title: String, origin: BrowsingTreeOrigin? = nil) -> BrowserTab {
        let tab = BrowserTab(state: state, browsingTreeOrigin: origin, originMode: .web, note: nil)
        tab.title = title
        return tab
    }


    func testMoveItemWithTabsOnly() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        sut.tabs = tabs
        sut.moveListItem(atListIndex: 3, toListIndex: 0, changeGroup: nil)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[0], tabs[1], tabs[2]])
        sut.moveListItem(atListIndex: 0, toListIndex: 1, changeGroup: nil)
        XCTAssertEqual(sut.tabs, [tabs[0], tabs[3], tabs[1], tabs[2]])
        sut.moveListItem(atListIndex: 0, toListIndex: 3, changeGroup: nil)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[1], tabs[2], tabs[0]])
        sut.moveListItem(atListIndex: 2, toListIndex: 1, changeGroup: nil)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[2], tabs[1], tabs[0]])
    }

    func testMoveItemAcrossGroup() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        let groupA = TabGroup(pageIds: [])
        var tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut.tabs = tabs
        sut._testSetTabsClusteringGroup(tabGroups)

        XCTAssertEqual(sut.listItems.allItems.count, 5)
        XCTAssertTrue(sut.listItems.allItems[1].isAGroupCapsule)
        XCTAssertEqual(sut.listItems.allItems.map { $0.group }, [nil, groupA, groupA, groupA, nil])

        sut.moveListItem(atListIndex: 4, toListIndex: 0, changeGroup: nil)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[0], tabs[1], tabs[2]])
        XCTAssertNil(sut.listItems.allItems[0].group)

        sut.moveListItem(atListIndex: 0, toListIndex: 1, changeGroup: nil)
        XCTAssertEqual(sut.tabs, [tabs[0], tabs[3], tabs[1], tabs[2]])
        XCTAssertNil(sut.listItems.allItems[1].group)


        sut.moveListItem(atListIndex: 0, toListIndex: 4, changeGroup: groupA)
        tabGroups[tabs[0].id] = groupA // we mock clustering group change
        sut._testSetTabsClusteringGroup(tabGroups)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[1], tabs[2], tabs[0]])
        XCTAssertEqual(sut.listItems.allItems.map { $0.group }, [nil, groupA, groupA, groupA, groupA])

        sut.moveListItem(atListIndex: 3, toListIndex: 2, changeGroup: groupA)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[2], tabs[1], tabs[0]])

        sut.moveListItem(atListIndex: 4, toListIndex: 0, changeGroup: nil)
        tabGroups[tabs[0].id] = nil // we mock clustering group change
        sut._testSetTabsClusteringGroup(tabGroups)
        XCTAssertEqual(sut.tabs, [tabs[0], tabs[3], tabs[2], tabs[1]])

        sut.moveListItem(atListIndex: 0, toListIndex: 2, changeGroup: groupA)
        tabGroups[tabs[0].id] = groupA // we mock clustering group change
        sut._testSetTabsClusteringGroup(tabGroups)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[0], tabs[2], tabs[1]])
        XCTAssertTrue(sut.listItems.allItems[1].isAGroupCapsule)
        XCTAssertEqual(sut.listItems.allItems[2].tab, tabs[0])

        sut.moveListItem(atListIndex: 2, toListIndex: 1, changeGroup: nil)
        tabGroups[tabs[0].id] = nil // we mock clustering group change
        sut._testSetTabsClusteringGroup(tabGroups)
        XCTAssertEqual(sut.tabs, [tabs[3], tabs[0], tabs[2], tabs[1]])
        XCTAssertTrue(sut.listItems.allItems[2].isAGroupCapsule)
        XCTAssertEqual(sut.listItems.allItems[1].tab, tabs[0])
    }

    func testShowNextPreviousTab() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        sut.tabs = tabs
        sut.setCurrentTab(at: 0)
        sut.showNextTab()
        sut.showNextTab()
        XCTAssertEqual(sut.currentTab, tabs[2])
        sut.showPreviousTab()
        XCTAssertEqual(sut.currentTab, tabs[1])
        sut.showNextTab()
        sut.showNextTab()
        sut.showNextTab()
        // loops back to beginning
        XCTAssertEqual(sut.currentTab, tabs[0])

        sut.showPreviousTab()
        // loops back to end
        XCTAssertEqual(sut.currentTab, tabs[3])
    }

    func testShowNextPreviousTabWithGroupCapsules() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        let groupA = TabGroup(pageIds: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut.tabs = tabs
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.setCurrentTab(at: 0)
        sut.showNextTab()
        sut.showNextTab()
        XCTAssertEqual(sut.currentTab, tabs[2])
        sut.showPreviousTab()
        XCTAssertEqual(sut.currentTab, tabs[1])
        sut.showNextTab()
        sut.showNextTab()
        sut.showNextTab()
        XCTAssertEqual(sut.currentTab, tabs[0])
        sut.showPreviousTab()
        XCTAssertEqual(sut.currentTab, tabs[3])
    }

    func testShowNextPreviousTabWithGroupCollapsed() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        let groupA = TabGroup(pageIds: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut.tabs = tabs
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.toggleGroupCollapse(groupA)
        XCTAssertEqual(sut.listItems.allItems.count, 3)
        sut.setCurrentTab(at: 0)
        sut.showNextTab()
        XCTAssertEqual(sut.currentTab, tabs[3])
        sut.showPreviousTab()
        XCTAssertEqual(sut.currentTab, tabs[0])
        sut.showNextTab()
        sut.showNextTab()
        XCTAssertEqual(sut.currentTab, tabs[0])
        sut.showPreviousTab()
        XCTAssertEqual(sut.currentTab, tabs[3])
    }

    func testSetCurrentTabAtIndex() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        sut.tabs = tabs
        sut.setCurrentTab(at: 0)
        XCTAssertEqual(sut.currentTab, tabs[0])

        sut.setCurrentTab(at: 3)
        XCTAssertEqual(sut.currentTab, tabs[3])

        sut.setCurrentTab(at: 1)
        XCTAssertEqual(sut.currentTab, tabs[1])

        sut.setCurrentTab(at: 9)
        // falls back to last tab
        XCTAssertEqual(sut.currentTab, tabs[3])
    }

    func testSetCurrentTabAtIndexWithGroupCollapsed() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        let groupA = TabGroup(pageIds: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut.tabs = tabs
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.toggleGroupCollapse(groupA)
        sut.setCurrentTab(at: 0)
        XCTAssertEqual(sut.currentTab, tabs[0])

        sut.setCurrentTab(at: 3)
        XCTAssertEqual(sut.currentTab, tabs[3])

        sut.setCurrentTab(at: 0)
        XCTAssertEqual(sut.currentTab, tabs[0])

        sut.setCurrentTab(at: 1)
        // tabs[3] is visually the next one
        XCTAssertEqual(sut.currentTab, tabs[3])

        sut.setCurrentTab(at: 2)
        XCTAssertEqual(sut.currentTab, tabs[3])
    }

    func testCollapseGroupGatherSeparatedTabs() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        let groupA = TabGroup(pageIds: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[3].id: groupA
        ]
        sut.tabs = tabs
        sut._testSetTabsClusteringGroup(tabGroups)
        XCTAssertEqual(sut.listItems.allItems.count, 5)
        XCTAssertEqual(sut.listItems.allItems[2].tab, tabs[1])
        XCTAssertEqual(sut.listItems.allItems[4].tab, tabs[3])

        sut.toggleGroupCollapse(groupA)
        XCTAssertEqual(sut.listItems.allItems.count, 3)

        // after uncollapsing, grouped tabs are now next to each other.
        sut.toggleGroupCollapse(groupA)
        XCTAssertEqual(sut.listItems.allItems[2].tab, tabs[1])
        XCTAssertEqual(sut.listItems.allItems[3].tab, tabs[3])
    }

    func testAddingAUnpinnedTabInsidePinnedTabIsNotPossible() {
        let (tabA, tabB, tabC, tabD) = (tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D"))
        sut.addNewTabAndNeighborhood(tabA, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabB, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabC, setCurrent: true)
        XCTAssertEqual(sut.tabs, [tabA, tabB, tabC])
        XCTAssertEqual(sut.currentTab, tabC)
        sut.pinTab(tabA)

        sut.addNewTabAndNeighborhood(tabD, setCurrent: true, at: 0)
        XCTAssertEqual(sut.tabs, [tabA, tabD, tabB, tabC])
        XCTAssertFalse(tabD.isPinned)
    }
}

// MARK: - Tabs Neighbooring
extension BrowserTabsManagerTests {
    func testRemoveTabSetClosestTabAsCurrent() {
        let (tabA, tabB, tabC, tabD) = (tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D"))
        sut.addNewTabAndNeighborhood(tabA, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabB, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabC, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabD, setCurrent: true)
        XCTAssertEqual(sut.tabs, [tabA, tabB, tabC, tabD])
        XCTAssertEqual(sut.currentTab, tabD)

        sut.setCurrentTab(at: 2)
        sut.removeTab(tabId: tabC.id)
        XCTAssertEqual(sut.currentTab, tabD)
        sut.removeTab(tabId: tabD.id)
        XCTAssertEqual(sut.currentTab, tabB)
        sut.removeTab(tabId: tabB.id)
        XCTAssertEqual(sut.currentTab, tabA)
        sut.removeTab(tabId: tabA.id)
        XCTAssertNil(sut.currentTab)
    }

    func testRemoveTabSetParentTabAsCurrent() {
        let (tabA, tabB, tabC) = (tab("Tab A"), tab("Tab B"), tab("Tab C"))
        sut.addNewTabAndNeighborhood(tabA, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabB, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabC, setCurrent: true)
        XCTAssertEqual(sut.tabs, [tabA, tabB, tabC])
        XCTAssertEqual(sut.currentTab, tabC)

        // Opening Tab D from cmd-click in tab A
        let tabD = tab("Tab D", origin: .browsingNode(id: UUID(), pageLoadId: nil, rootOrigin: tabA.browsingTree.origin.rootOrigin, rootId: tabA.browsingTree.rootId))
        sut.addNewTabAndNeighborhood(tabD, setCurrent: true)
        XCTAssertEqual(sut.currentTab, tabD)
        sut.removeTab(tabId: tabD.id)
        XCTAssertEqual(sut.currentTab, tabA)

        // Opening Tab E from cmd-T in tab B
        let tabE = tab("Tab E", origin: .searchBar(query: "E", referringRootId: tabB.browsingTree.rootId))
        sut.addNewTabAndNeighborhood(tabE, setCurrent: true)
        XCTAssertEqual(sut.currentTab, tabE)
        sut.removeTab(tabId: tabE.id)
        XCTAssertEqual(sut.currentTab, tabB)
    }

    func testRemoveTabDoesntSetPinnedTabAsCurrent() {
        let (tabA, tabB, tabC) = (tab("Tab A"), tab("Tab B"), tab("Tab C"))
        sut.addNewTabAndNeighborhood(tabA, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabB, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabC, setCurrent: true)
        XCTAssertEqual(sut.tabs, [tabA, tabB, tabC])
        XCTAssertEqual(sut.currentTab, tabC)
        sut.pinTab(tabA)

        // Opening Tab D from cmd-click in tab A
        let tabD = tab("Tab D", origin: .browsingNode(id: UUID(), pageLoadId: nil, rootOrigin: tabA.browsingTree.origin.rootOrigin, rootId: tabA.browsingTree.rootId))
        sut.addNewTabAndNeighborhood(tabD, setCurrent: true)
        XCTAssertEqual(sut.currentTab, tabD)
        sut.removeTab(tabId: tabD.id)
        // tab A is not selected because it's Pinned
        XCTAssertNotEqual(sut.currentTab, tabA)
        XCTAssertEqual(sut.currentTab, tabC)

        sut.setCurrentTab(tabB)
        sut.removeTab(tabId: tabB.id)
        XCTAssertNotEqual(sut.currentTab, tabA)
        XCTAssertEqual(sut.currentTab, tabC)
    }

    func testRemoveTabSetSuggestedTabAsCurrent() {
        let (tabA, tabB, tabC, tabD) = (tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D"))
        sut.addNewTabAndNeighborhood(tabA, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabB, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabC, setCurrent: true)
        sut.addNewTabAndNeighborhood(tabD, setCurrent: true)
        XCTAssertEqual(sut.tabs, [tabA, tabB, tabC, tabD])
        XCTAssertEqual(sut.currentTab, tabD)
        sut.removeTab(tabId: tabD.id, suggestedNextCurrentTab: tabB)
        XCTAssertEqual(sut.currentTab, tabB)
    }

}

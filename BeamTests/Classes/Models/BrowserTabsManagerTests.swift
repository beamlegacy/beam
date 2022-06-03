//
//  BrowserTabsManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 19/05/2022.
//

import XCTest
@testable import Beam

class BrowserTabsManagerTests: XCTestCase {

    lazy var state = BeamState()
    var sut: BrowserTabsManager!

    override func setUp() {
        sut = BrowserTabsManager(with: state.data, state: state)
    }

    private func tab(_ title: String) -> BrowserTab {
        let tab = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .web, note: nil)
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
        let groupA = TabClusteringGroup(pageIDs: [])
        var tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.tabs = tabs

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
        let groupA = TabClusteringGroup(pageIDs: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut._testSetTabsClusteringGroup(tabGroups)
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
        XCTAssertEqual(sut.currentTab, tabs[0])
        sut.showPreviousTab()
        XCTAssertEqual(sut.currentTab, tabs[3])
    }

    func testShowNextPreviousTabWithGroupCollapsed() {
        let tabs = [
            tab("Tab A"), tab("Tab B"), tab("Tab C"), tab("Tab D")
        ]
        let groupA = TabClusteringGroup(pageIDs: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.tabs = tabs
        sut.toggleGroupCollapse(groupA.id)
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
        let groupA = TabClusteringGroup(pageIDs: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[2].id: groupA
        ]
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.tabs = tabs
        sut.toggleGroupCollapse(groupA.id)
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
        let groupA = TabClusteringGroup(pageIDs: [])
        let tabGroups = [
            tabs[1].id: groupA,
            tabs[3].id: groupA
        ]
        sut._testSetTabsClusteringGroup(tabGroups)
        sut.tabs = tabs
        XCTAssertEqual(sut.listItems.allItems.count, 5)
        XCTAssertEqual(sut.listItems.allItems[2].tab, tabs[1])
        XCTAssertEqual(sut.listItems.allItems[4].tab, tabs[3])

        sut.toggleGroupCollapse(groupA.id)
        XCTAssertEqual(sut.listItems.allItems.count, 3)

        // after uncollapsing, grouped tabs are now next to each other.
        sut.toggleGroupCollapse(groupA.id)
        XCTAssertEqual(sut.listItems.allItems[2].tab, tabs[1])
        XCTAssertEqual(sut.listItems.allItems[3].tab, tabs[3])
    }
}

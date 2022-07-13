//
//  TabGroupingStoreManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/06/2022.
//

import XCTest
@testable import Beam

class TabGroupingStoreManagerTests: XCTestCase {

    var sut:TabGroupingStoreManager!

    override func setUp() {
        sut = BeamData.shared.tabGroupingDBManager
    }
    
    override class func tearDown() {
        try? BeamData.shared.tabGroupingDBManager?.clear()
    }

    func tab(withPageId pageId: UUID) -> BrowserTab {
        let tab = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .web, note: nil)
        tab.url = URL(string: "beamapp.co")
        tab.browsingTree.current.link = pageId
        return tab
    }

    @MainActor
    func testGroupIsSavedWhenUserChangesMetadata() async {
        let group = TabGroup(pageIds: [])
        var saved = await sut.groupDidUpdate(group, origin: .userGroupMetadataChange, openTabs: [])
        XCTAssertFalse(saved) // no title, not saved

        group.changeTitle("New Title")
        saved = await sut.groupDidUpdate(group, origin: .userGroupMetadataChange, openTabs: [])
        XCTAssertTrue(saved)

        group.changeColor(.init())
        saved = await sut.groupDidUpdate(group, origin: .userGroupMetadataChange, openTabs: [])
        XCTAssertTrue(saved)
    }

    @MainActor
    func testGroupIsSavedWhenClusteringAddPages() async {
        var ids = [UUID(), UUID()]
        var tabs = ids.map { tab(withPageId: $0) }
        let group = TabGroup(pageIds: ids, title: "Title")
        var saved = await sut.groupDidUpdate(group, origin: .clustering, openTabs: tabs)
        XCTAssertTrue(saved)

        // same pages, no save
        saved = await sut.groupDidUpdate(group, origin: .clustering, openTabs: tabs)
        XCTAssertFalse(saved)

        ids.append(UUID())
        tabs = ids.map { tab(withPageId: $0) }
        group.updatePageIds(ids)
        // adding page, we save
        saved = await sut.groupDidUpdate(group, origin: .clustering, openTabs: tabs)
        XCTAssertTrue(saved)

        ids.removeLast()
        tabs = ids.map { tab(withPageId: $0) }
        group.updatePageIds(ids)
        // less pages, no save
        saved = await sut.groupDidUpdate(group, origin: .clustering, openTabs: tabs)
        XCTAssertFalse(saved)

    }

    @MainActor
    func testGroupIsSavedWhenUserChangePages() async {
        var ids = [UUID(), UUID()]
        var tabs = ids.map { tab(withPageId: $0) }
        let group = TabGroup(pageIds: ids, title: "Title")
        var saved = await sut.groupDidUpdate(group, origin: .clustering, openTabs: tabs)
        XCTAssertTrue(saved)

        ids.append(UUID())
        tabs = ids.map { tab(withPageId: $0) }
        group.updatePageIds(ids)
        // adding page, we save
        saved = await sut.groupDidUpdate(group, origin: .userGroupReordering, openTabs: tabs)
        XCTAssertTrue(saved)

        ids.removeLast()
        tabs = ids.map { tab(withPageId: $0) }
        group.updatePageIds(ids)
        // less pages from user, we save
        saved = await sut.groupDidUpdate(group, origin: .userGroupReordering, openTabs: tabs)
        XCTAssertTrue (saved)
    }


}

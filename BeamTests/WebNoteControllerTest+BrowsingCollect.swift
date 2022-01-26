//
//  WebNoteControllerTest+BrowsingCollect.swift
//  BeamTests
//
//  Created by Stef Kors on 10/01/2022.
//

import XCTest

@testable import Beam
@testable import BeamCore

class WebNoteControllerTest_BrowsingCollect: XCTestCase {
    var note: BeamNote!
    var searchElement: BeamElement!
    var controller: WebNoteController!
    let websiteTitle = "Some website"
    let url = URL(string: "https://www.website.com")!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        note = BeamNote(title: "Sample note")
        // Add text "lama" to start search
        searchElement = BeamElement("lama")
        note.addChild(searchElement)
        controller = WebNoteController(note: note)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCollect_initalNote() throws {
        guard let noteChildren = controller.note?.children,
              let lastChild = noteChildren.last else {
                  XCTFail("Expected atlast one child element on note")
                  return
              }

        XCTAssertEqual(noteChildren.count, 1)
        XCTAssertEqual(lastChild, searchElement)
    }

    func testCollect_DefaultPreference() throws {
        XCTAssertFalse(PreferencesManager.browsingSessionCollectionIsOn, "Browsing Session Collection is expected to be turned OFF by default")
    }

    func testCollect_Enabled_Add_One() throws {
        // Enable Browsing Collect
        PreferencesManager.browsingSessionCollectionIsOn = true
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = true

        // When the user visits a page, add url to note
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: searchElement.text.text)
        let added = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)

        guard let noteChildren = controller.note?.children,
              let lastChild = noteChildren.last else {
                  XCTFail("Expected atlast one child element on note")
                  return
              }

        XCTAssertEqual(noteChildren.count, 2)
        XCTAssertEqual(lastChild, added)
    }

    func testCollect_Enabled_Add_Two() throws {
        // Enable Browsing Collect
        PreferencesManager.browsingSessionCollectionIsOn = true
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = true

        // When the user visits a page, add url to note
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: searchElement.text.text)
        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        // Add second
        let secondAdd = controller.add(url: URL(string: "http://some.linked.website")!, text: "Some linked website", reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)

        guard let noteChildren = controller.note?.children,
              let lastChild = noteChildren.last else {
                  XCTFail("Expected atlast one child element on note")
                  return
              }

        XCTAssertEqual(noteChildren.count, 3) // New bullet, not nested
        XCTAssertEqual(lastChild, secondAdd)
    }

    func testCollect_Enabled_Add_Two_Deduplicate() throws {
        // Enable Browsing Collect
        PreferencesManager.browsingSessionCollectionIsOn = true
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = true

        // When the user visits a page, add url to note
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: searchElement.text.text)
        let firstAdd = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        // Add same second
        let secondAdd = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)

        guard let noteChildren = controller.note?.children,
              let lastChild = noteChildren.last else {
                  XCTFail("Expected atlast one child element on note")
                  return
              }

        XCTAssertEqual(noteChildren.count, 2) // Still one, no add
        XCTAssertEqual(lastChild, secondAdd)
        XCTAssertEqual(firstAdd, secondAdd)
    }

    func testCollect_Enabled_Add_Three_Paralel() throws {
        // Enable Browsing Collect
        PreferencesManager.browsingSessionCollectionIsOn = true
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = true

        // When the user visits a page, add url to note
        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: searchElement.text.text)
        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        // Add second
        let _ = controller.add(url: URL(string: "http://some.linked.website")!, text: "Some linked website", reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        // Add third paralel
        let parallelAdd = controller.add(url: URL(string: "http://some.other")!, text: "Some parallel website", reason: .loading, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)

        guard let noteChildren = controller.note?.children,
              let lastChild = noteChildren.last else {
                  XCTFail("Expected atlast one child element on note")
                  return
              }

        XCTAssertEqual(noteChildren.count, 4) // Still one, other is nested
        XCTAssertEqual(lastChild, parallelAdd)
    }

    func testCollect_Disabled_Preference_false() throws {
        // Disable Preference
        PreferencesManager.browsingSessionCollectionIsOn = false
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = true

        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: searchElement.text.text)
        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        let noteChildren = controller.note?.children ?? []
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: URL(string: "http://some.linked.website")!, text: "Some linked website", reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: URL(string: "http://some.other")!, text: "Some parallel website", reason: .loading, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)
    }

    func testCollect_Disabled_Not_Navigated_From_Note() throws {
        // Disable Preference
        PreferencesManager.browsingSessionCollectionIsOn = true
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = false

        let origin = BrowsingTreeOrigin.searchFromNode(nodeText: searchElement.text.text)
        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        let noteChildren = controller.note?.children ?? []
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: URL(string: "http://some.linked.website")!, text: "Some linked website", reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: URL(string: "http://some.other")!, text: "Some parallel website", reason: .loading, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)
    }

    func testCollect_Disabled_No_Origin_Node() throws {
        // Disable Preference
        PreferencesManager.browsingSessionCollectionIsOn = true
        defer { PreferencesManager.browsingSessionCollectionIsOn = false }
        let isNavigatingFromNote = true

        let origin: BrowsingTreeOrigin? = nil
        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        let noteChildren = controller.note?.children ?? []
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: url, text: websiteTitle, reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: URL(string: "http://some.linked.website")!, text: "Some linked website", reason: .navigation, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)

        let _ = controller.add(url: URL(string: "http://some.other")!, text: "Some parallel website", reason: .loading, isNavigatingFromNote: isNavigatingFromNote, browsingOrigin: origin)
        XCTAssertEqual(noteChildren.count, 1)
    }
}

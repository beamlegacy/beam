//
//  BeamTextEditTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 06/09/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

class BeamTextEditTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCopyPasteUrls() throws {
        func pasteAndCheckNoteSourceFor(url: String) throws {
            editor.paste("")
            let urlId  = try XCTUnwrap(LinkStore.getIdFor(url))
            XCTAssertNotNil(note.sources.get(urlId: urlId))
            pasteboard.clearContents()
        }


        let note = BeamNote(title: "A few interesting urls")
        let data = BeamData()
        let editor = BeamTextEdit(root: note, journalMode: false)
        editor.data = data
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        XCTAssertEqual(note.sources.count, 0)
        let urls = [
            "http://awe.some",
            "http://fantas.tic",
            "http://wonder.ful",
            "http://miraculo.us",
        ]

        //Pasting raw string
        var url = urls[0]
        pasteboard.setString("abc \n\(url) efg", forType: .string)
        try pasteAndCheckNoteSourceFor(url: url)

        //Pasting NSattributedString
        url = urls[1]
        let nSString = NSMutableAttributedString(string: "abc \n\(url) efg")
        let docAttrRtf: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: NSAttributedString.DocumentType.rtf, .characterEncoding: String.Encoding.utf8]
        let rtfData = try nSString.data(from: NSRange(location: 0, length: nSString.length), documentAttributes: docAttrRtf)
        pasteboard.setData(rtfData, forType: .rtf)
        try pasteAndCheckNoteSourceFor(url: url)

        //Pasting BeamTextHolder
        url = urls[2]
        let bTextHolder = BeamTextHolder(bText: BeamText(attributedString: NSAttributedString(string: "abc \n\(url) efg")))
        let beamTextData = try PropertyListEncoder().encode(bTextHolder)
        pasteboard.setData(beamTextData, forType: .bTextHolder)
        try pasteAndCheckNoteSourceFor(url: url)

        //Pasting BeamElements
        url = urls[3]
        let fromNote = BeamNote(title: "note to copy")
        fromNote.addChild(BeamElement(BeamText(attributedString: NSAttributedString(string: "abc \n\(url) efg"))))
        let noteData = try JSONEncoder().encode(fromNote)
        let elementHolder = BeamNoteDataHolder(noteData: noteData)
        let elementHolderData = try PropertyListEncoder().encode(elementHolder)
        pasteboard.setData(elementHolderData, forType: .noteDataHolder)
        try pasteAndCheckNoteSourceFor(url: url)

        XCTAssertEqual(note.sources.count, 4)

        //Checking that urls have been added active notesources
        let activeSources = data.activeSources.activeSources
        XCTAssertEqual(activeSources.count, 1)
        let pastedNoteSources = try XCTUnwrap(activeSources[note.id])
        XCTAssertEqual(pastedNoteSources.count, 4)
        let expectedSources = urls.compactMap(LinkStore.getIdFor)
        XCTAssertEqual(Set(pastedNoteSources), Set(expectedSources))
    }

    func testLinkStringForPrecedingCharacters() {
        let note = BeamNote(title: "BeamTextEditTests")
        let editor = BeamTextEdit(root: note, journalMode: false)
        let root = editor.rootNode!

        let bullet = BeamElement("Some text and a link.com")
        let node = TextNode(parent: root, element: bullet)

        XCTAssertNil(editor.linkStringForPrecedingCharacters(atIndex: 10, in: node))

        let result = editor.linkStringForPrecedingCharacters(atIndex: node.textCount, in: node)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, "https://link.com")
        XCTAssertEqual(result?.1, node.textCount-8 ..< node.textCount)
    }
}

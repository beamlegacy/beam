import XCTest

@testable import Beam
@testable import BeamCore

class WebNoteControllerTest: XCTestCase {
    class MockSocialTitleFetcher: SocialTitleFetcher {
        static func getDefaultLinkTitle(url: URL) -> String {
            "\(url.hostname ?? "") Enterprise Solutions"
        }
        func getMockTitle(_ url: URL) throws -> SocialTitle? {
            SocialTitle(url: url, title: "\(url.hostname ?? "") Enterprise Solutions")
        }
        override func fetch(for url: URL, completion: @escaping (Result<SocialTitle?, SocialTitleFetcherError>) -> Void) {
            let result = Result(catching: {
                try getMockTitle(url)
            }).mapError({ _ in
                SocialTitleFetcherError.failedRequest
            })
            completion(result)
        }
    }

    var words = WordsFile()
    var note = BeamNote(title: "Sample note")

    override func setUpWithError() throws {
        note = BeamNote(title: "Sample note")
        SocialTitleFetcher.shared = MockSocialTitleFetcher()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    func createMockParagraph() -> BeamElement {
        BeamElement(createMockWords(5).joined(separator: " "))
    }

    func createMockWords(_ count: Int = 1) -> [String] {
        (0..<count).map { _ in words?.randomWord() ?? "" }
    }

    func testCreateFromNote() throws {
        let controller = WebNoteController(note: note)
        XCTAssertEqual(controller.note, note)
        XCTAssertEqual(controller.rootElement, note)
        XCTAssertEqual(controller.element, note)
    }

    func testCreateFromElement() throws {
        let child1 = BeamElement("child 1")
        note.addChild(child1)
        let child2 = BeamElement("child 2")
        note.addChild(child2)
        let root = note.children[1]

        let controller = WebNoteController(note: note, rootElement: root)

        XCTAssertEqual(controller.note, note)
        XCTAssertEqual(controller.rootElement, root)
        XCTAssertTrue(note != root)
        let element = controller.element
        XCTAssertNotEqual(element, note)
        XCTAssertEqual(element, root)
    }

    func testMultipleParagraphsOfSameSourceShouldNestCorrectly() async throws {
        let controller = WebNoteController(note: note)
        let sourceLink = URL(string: "https://www.example.com")!
        let paragraph1 = BeamElement("example content with a lot of words")
        let paragraph1V2 = BeamElement("example content with a lot of words")
        let paragraph2 = createMockParagraph()
        ///
        /// 1. AddContent
        /// SourceLink
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink, reason: .pointandshoot)
        ///
        /// 2. AddContent
        /// SourceLink
        /// - Paragraph1V2
        /// - Paragraph2
        await controller.addContent(content: [paragraph1V2, paragraph2], with: sourceLink, reason: .pointandshoot)
        ///
        /// Expect the note to look like:
        /// SourceLink
        /// - Paragraph1
        /// - Paragraph1V2
        /// - Paragraph2
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.children, [paragraph1, paragraph1V2, paragraph2])
        }
    }

    func testMultipleParagraphsOfDifferentSourceShouldCreateMultipleSourceLinks() async throws {
        let controller = WebNoteController(note: note)
        let sourceLink1 = URL(string: "https://www.one.com")!
        let sourceLink2 = URL(string: "https://www.two.com")!
        let paragraph1 = BeamElement("example content with a lot of words")
        let paragraph1V2 = BeamElement("example content with a lot of words")
        let paragraph2 = createMockParagraph()
        ///
        /// 1. AddContent
        /// SourceLink1
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink1, reason: .pointandshoot)
        ///
        /// 2. AddContent
        /// SourceLink2
        /// - Paragraph1V2
        /// - Paragraph2
        await controller.addContent(content: [paragraph1V2, paragraph2], with: sourceLink2, reason: .pointandshoot)
        ///
        /// Expect the note to look like:
        /// SourceLink
        /// - Paragraph1
        /// - Paragraph1V2
        /// SourceLink2
        /// - Paragraph2
        XCTAssertEqual(controller.note?.children.count, 2)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.text.links, [sourceLink1.absoluteString])
            XCTAssertEqual(firstChild.children, [paragraph1])
        }

        if let child = controller.note?.children[1] {
            XCTAssertEqual(child.text.links, [sourceLink2.absoluteString])
            XCTAssertEqual(child.children, [paragraph1V2, paragraph2])
        }
    }

    func testAddContentShouldUseFirstEmptyBulletInEmptyNote() async throws {
        ///
        /// Note Before:
        /// - <empty bullet with no content>
        let emptyBullet = BeamElement("")
        note.addChild(emptyBullet)
        let controller = WebNoteController(note: note)
        ///
        let sourceLink = URL(string: "https://www.example.com")!
        let paragraph1 = BeamElement("example content with a lot of words")
        ///
        /// 1. AddContent
        /// SourceLink
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink, reason: .pointandshoot)
        ///
        /// Expect the note to look like:
        /// 1. AddContent
        /// SourceLink
        /// - Paragraph1
        ///
        /// NOT:
        /// 1. AddContent
        /// - <empty bullet with no content>
        /// SourceLink
        /// - Paragraph1
        ///
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.children, [paragraph1])
        }

    }

    func testAddContentShouldUseSkipBulletContainingSpace() async throws {
        ///
        /// Note Before:
        /// - " "
        let emptyBullet = BeamElement(" ")
        note.addChild(emptyBullet)
        let controller = WebNoteController(note: note)
        ///
        let sourceLink = URL(string: "https://www.example.com")!
        let paragraph1 = BeamElement("example content with a lot of words")
        ///
        /// 1. AddContent
        /// SourceLink
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink, reason: .pointandshoot)
        ///
        /// Expect the note to look like:
        /// 1. AddContent
        /// - " "
        /// SourceLink
        /// - Paragraph1
        ///
        XCTAssertEqual(controller.note?.children.count, 2)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild, emptyBullet)
        }

        if let child = controller.note?.children[1] {
            XCTAssertEqual(child.children, [paragraph1])
        }

    }


    func testAddContentShouldNotCreateNewBulletWhenLastBulletIsEmpty() async throws {
        let sourceLink = URL(string: "https://www.example.com")!
        let paragraph1 = createMockParagraph()
        let paragraph2 = createMockParagraph()
        let controller = WebNoteController(note: note)
        ///
        /// 1. AddContent
        /// SourceLink
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink, reason: .pointandshoot)
        ///
        /// An empty bullet gets added
        let emptyBullet = BeamElement("")
        await MainActor.run {
            controller.element.addChild(emptyBullet)
        }
        ///
        /// Assert it looks like:
        /// SourceLink
        /// - Paragraph1
        /// - <empty bullet with no content>
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.children, [paragraph1, emptyBullet])
        }
        /// 2. AddContent
        /// SourceLink
        /// - Paragraph2
        await controller.addContent(content: [paragraph2], with: sourceLink, reason: .pointandshoot)
        ///
        /// Expect the note to look like:
        /// SourceLink
        /// - Paragraph1
        /// - Paragraph2
        ///
        /// NOT:
        /// SourceLink
        /// - Paragraph1
        /// - <empty bullet with no content>
        ///
        /// or:
        /// 
        /// SourceLink
        /// - Paragraph1
        /// - <empty bullet with no content>
        /// - Paragraph2
        ///
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.children, [paragraph1, paragraph2])
        }
    }

    func testAddContentShouldAddToSourceBulletEvenIfItsNotTheLastBullet() async throws {
        let sourceLink1 = URL(string: "https://www.one.com")!
        let sourceLink2 = URL(string: "https://www.two.com")!
        let paragraph1 = createMockParagraph()
        let paragraph2 = createMockParagraph()
        let paragraph3 = createMockParagraph()
        let controller = WebNoteController(note: note)
        await controller.addContent(content: [paragraph1], with: sourceLink1, reason: .pointandshoot)
        await controller.addContent(content: [paragraph2], with: sourceLink2, reason: .pointandshoot)
        ///
        /// Assert Note Before
        ///
        /// SourceLink1
        /// - Paragraph1
        /// SourceLink2
        /// - Paragraph2
        ///
        XCTAssertEqual(controller.note?.children.count, 2)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.children.count, 1)
            XCTAssertEqual(firstChild.children, [paragraph1])
        }
        if let child = controller.note?.children[1] {
            XCTAssertEqual(child.children.count, 1)
            XCTAssertEqual(child.children, [paragraph2])
        }

        /// 1. AddContent (source: SourceLink1)
        /// SourceLink1
        /// - Paragraph3
        await controller.addContent(content: [paragraph3], with: sourceLink1, reason: .pointandshoot)
        ///
        /// Note After
        /// SourceLink1
        /// - Paragraph1
        /// - Paragraph3    <<<<<<
        /// SourceLink2
        /// - Paragraph2
        XCTAssertEqual(controller.note?.children.count, 2)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.children.count, 2)
            XCTAssertEqual(firstChild.children[0], paragraph1)
            // XCTAssertEqual(firstChild.children[1], paragraph3)
        }

        if let child = controller.note?.children[1] {
            XCTAssertEqual(child.children.count, 1)
            XCTAssertEqual(child.children.first, paragraph2)
        }

    }

    func testSourceLinkWithManuallyUpdatedTitleShouldNotOverwriteTitle() async throws {
        let sourceLink1 = URL(string: "https://www.one.com")!
        let updatedLinkTitle = "updated link title"
        let paragraph1 = createMockParagraph()
        let paragraph2 = createMockParagraph()
        let controller = WebNoteController(note: note)
        /// 1. AddContent (source: SourceLink1)
        /// SourceLink1
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink1, reason: .pointandshoot)
        ///
        /// Manually update link text
        await MainActor.run {
            controller.note?.children.first?.text = BeamText(updatedLinkTitle, attributes: [.link(sourceLink1.absoluteString)])
        }
        ///
        /// 1. AddContent (source: SourceLink1)
        /// SourceLink1
        /// - Paragraph1
        /// - Paragraph2
        ///
        await controller.addContent(content: [paragraph2], with: sourceLink1, reason: .pointandshoot)
        ///
        /// Assert SourceLink1 still has manually set link text
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.text.text, updatedLinkTitle)
            XCTAssertEqual(firstChild.children, [paragraph1, paragraph2])
        }
    }

    func testWhenBulletHasMoreContentThanOnlyTheSourceLinkDontUseThatBulletAsSourceLink() async throws {
        let sourceLink1 = URL(string: "https://go.dev/doc/")!
        let defaultLinkTitle = MockSocialTitleFetcher.getDefaultLinkTitle(url: sourceLink1)
        let updatedLinkTitle = "\(defaultLinkTitle) bla bla bla golang is super cool"
        let paragraph1 = createMockParagraph()
        let paragraph2 = createMockParagraph()
        let controller = WebNoteController(note: note)
        /// Usual behaviour:
        /// 1. AddContent
        /// https://go.dev/doc/
        /// - Paragraph1
        ///
        /// 2. AddContent
        /// https://go.dev/doc/
        /// - Paragraph1
        /// - Paragraph2
        ///
        /// Expect new bullet when SourceLink is not just link
        /// 1. AddContent
        /// https://go.dev/doc/ "bla bla bla golang is super cool"
        /// - Paragraph1
        ///
        /// 2. AddContent
        /// https://go.dev/doc/ "bla bla bla golang is super cool"
        /// - Paragraph1
        /// https://go.dev/doc/
        /// - Paragraph2
        ///
        /// --------
        ///
        /// 1. AddContent (source: SourceLink1)
        /// SourceLink1
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink1, reason: .pointandshoot)
        ///
        /// Manually add plain beam text content
        await MainActor.run {
            controller.note?.children.first?.text.append(" bla bla bla golang is super cool", withAttributes: [])
        }
        ///
        /// Assert it looks like
        /// https://go.dev/doc/ "bla bla bla golang is super cool"
        /// - Paragraph1
        ///
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.text.text, updatedLinkTitle)
            XCTAssertEqual(firstChild.children, [paragraph1])
        }
        ///
        /// 1. AddContent
        /// SourceLink1
        /// - Paragraph2
        await controller.addContent(content: [paragraph2], with: sourceLink1, reason: .pointandshoot)
        ///
        /// Assert It looks like:
        /// https://go.dev/doc/ "bla bla bla golang is super cool"
        /// - Paragraph1
        /// https://go.dev/doc/
        /// - Paragraph2
        XCTAssertEqual(controller.note?.children.count, 2)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.text.text, updatedLinkTitle)
            XCTAssertEqual(firstChild.children, [paragraph1])
        }

        if let child = controller.note?.children[1] {
            XCTAssertEqual(child.text.text, defaultLinkTitle)
            XCTAssertEqual(child.children, [paragraph2])
        }
    }

    func testSearchOnNoteConvertsSearchTextToLink() async throws {
        let search = "Surfing in Scheveningen"
        let searchText = BeamElement(search)
        note.addChild(searchText)
        let controller = WebNoteController(note: note)
        
        await controller.replaceSearchWithSearchLink(
            search,
            url: URL(string: "https://www.google.com/search?q=Surfing%20in%20Scheveningen")!
        )

        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.text.text, search)
            XCTAssertEqual(firstChild.children, [])
        }
    }
}

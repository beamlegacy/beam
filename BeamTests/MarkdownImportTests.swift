import XCTest
import BeamCore
@testable import Beam

final class MarkdownImportTests: XCTestCase {

    let importer: MarkdownImporter = MarkdownImporter()

    func testEmptyImport() throws {
        let markdown = ""
        let note = try importer._import(markdown: markdown)
        XCTAssertTrue(note.children.isEmpty)
    }

    func testSimpleContent() throws {
        let markdown = "Here is *some* **Markdown** content."
        let note = try importer._import(markdown: markdown)
        XCTAssertEqual(note.children.count, 1)
        let element = note.children[0]
        XCTAssertEqual(element.kind, .bullet)
        let range0 = element.text.ranges[0]
        XCTAssertEqual(range0.string, "Here is ")
        XCTAssertTrue(range0.attributes.isEmpty)
        let range1 = element.text.ranges[1]
        XCTAssertEqual(range1.string, "some")
        XCTAssertEqual(range1.attributes.count, 1)
        XCTAssertEqual(range1.attributes[0], .emphasis)
        let range2 = element.text.ranges[2]
        XCTAssertEqual(range2.string, " ")
        XCTAssertTrue(range2.attributes.isEmpty)
        let range3 = element.text.ranges[3]
        XCTAssertEqual(range3.string, "Markdown")
        XCTAssertEqual(range3.attributes.count, 1)
        XCTAssertEqual(range3.attributes[0], .strong)
        let range4 = element.text.ranges[4  ]
        XCTAssertEqual(range4.string, " content.")
        XCTAssertTrue(range4.attributes.isEmpty)
    }

    func testSimpleElements() throws {
        let markdown = """
        Element 1 with *some* **text**  
        Element 2  
        Element 3 with *some* **more text**  
        """
        let note = try importer._import(markdown: markdown)
        // in the markdown string, these elements contain at the end line breaks so they're splitted into 3 elements
        // which is the markdown you'll get when you export a BeamNote with 3 children like we test below
        XCTAssertEqual(note.children.count, 3)
        XCTAssertEqual(note.children[0].text.text, "Element 1 with some text")
        XCTAssertEqual(note.children[1].text.text, "Element 2")
        XCTAssertEqual(note.children[2].text.text, "Element 3 with some more text")
    }

    func testSimpleList() throws {
        let markdown = """
          * *Element 1*
          * **Element 2**
          * Element 3
        """
        let note = try importer._import(markdown: markdown)
        XCTAssertEqual(note.children.count, 1)
        // this is imported as a single node with 3 children
        // whereas in the `testSimpleElements` test, those are imported as 3 distinct elements
        let list = note.children[0]
        XCTAssertEqual(list.children[0].text.text, "Element 1")
        XCTAssertEqual(list.children[1].text.text, "Element 2")
        XCTAssertEqual(list.children[2].text.text, "Element 3")
    }

    func testNestedLists() throws {
        let markdown = """
          * Element 1
          * Element 2
            * *Sub* Element 4
              * **Sub** *Sub* Element 6
            * **Sub** Element 5
          * Element 3
        """
        let note = try importer._import(markdown: markdown)
        XCTAssertEqual(note.children.count, 1)
        let list = note.children[0]
        XCTAssertEqual(list.children.count, 3)
        XCTAssertEqual(list.children[0].text.text, "Element 1")
        XCTAssertEqual(list.children[2].text.text, "Element 3")
        let subList = list.children[1]
        XCTAssertEqual(subList.children.count, 2)
        XCTAssertEqual(subList.text.text, "Element 2")
        XCTAssertEqual(subList.children[1].text.text, "Sub Element 5")
        let subSubList = subList.children[0]
        XCTAssertEqual(subSubList.children.count, 1)
        XCTAssertEqual(subSubList.text.text, "Sub Element 4")
        XCTAssertEqual(subSubList.children[0].text.text, "Sub Sub Element 6")
    }

    func testGroupedList() throws {
        let markdown = """
        # Some heading

          * Element 1
          * Element 2
            * *Sub* Element 4
              * **Sub** *Sub* Element 6
            * **Sub** Element 5
          * Element 3
        """
        let note = try importer._import(markdown: markdown)
        XCTAssertEqual(note.children.count, 1)
        XCTAssertEqual(note.children[0].kind, .heading(1))
        XCTAssertEqual(note.children[0].text.text, "Some heading")
        let list = note.children[0]
        XCTAssertEqual(list.children.count, 3)
        XCTAssertEqual(list.children[0].text.text, "Element 1")
        XCTAssertEqual(list.children[2].text.text, "Element 3")
        let subList = list.children[1]
        XCTAssertEqual(subList.children.count, 2)
        XCTAssertEqual(subList.text.text, "Element 2")
        XCTAssertEqual(subList.children[1].text.text, "Sub Element 5")
        let subSubList = subList.children[0]
        XCTAssertEqual(subSubList.children.count, 1)
        XCTAssertEqual(subSubList.text.text, "Sub Element 4")
        XCTAssertEqual(subSubList.children[0].text.text, "Sub Sub Element 6")
    }

    func testWithLineBreaks() throws {
        let markdown = """
        Beam lets you **capture** anything you want on the web:

          * **Hold ⌥ OPTION** on your keyboard and click on what you want to capture
          * Select text and press **⌥ OPTION** to capture the text snippet
          * Press **⌘S or ⌥S** to capture a whole page

        <br>
        Below are a few examples:  
        <br>

        ## Text

        [Bright Paper - beam](https://public.beamapp.co/beam/note/c5ef3f23-5864-45ad-943e-b75b093555e1/Bright-Paper)

          * Our tools define our relationship with the world. Web browsers have framed our cognitive behavior to such an extent we don’t question it anymore. Can thinking be reduced to a search box with no memory or context? What is left of the thousands hours you spent on the web

        <br>
        """
        let note = try importer._import(markdown: markdown)
        XCTAssertEqual(note.children.count, 7)

        let firstBullet = note.children[0]
        XCTAssertEqual(firstBullet.text.text, "Beam lets you capture anything you want on the web:")
        XCTAssertEqual(firstBullet.children.count, 3)
        XCTAssertEqual(firstBullet.children[0].text.text, "Hold ⌥ OPTION on your keyboard and click on what you want to capture")
        XCTAssertEqual(firstBullet.children[1].text.text, "Select text and press ⌥ OPTION to capture the text snippet")
        XCTAssertEqual(firstBullet.children[2].text.text, "Press ⌘S or ⌥S to capture a whole page")

        XCTAssertTrue(note.children[1].text.isEmpty)

        XCTAssertEqual(note.children[2].text.text, "Below are a few examples:")

        XCTAssertEqual(note.children[4].kind, .heading(2))
        XCTAssertEqual(note.children[4].text.text, "Text")
        XCTAssertTrue(note.children[4].children.isEmpty)

        let linkNode = note.children[5]
        XCTAssertEqual(linkNode.children.count, 1)
        XCTAssertEqual(linkNode.text.ranges.count, 1)
        XCTAssertEqual(linkNode.text.ranges[0].string, "Bright Paper - beam")
        XCTAssertEqual(
            linkNode.text.ranges[0].attributes[0],
            .link("https://public.beamapp.co/beam/note/c5ef3f23-5864-45ad-943e-b75b093555e1/Bright-Paper")
        )
        XCTAssertEqual(
            linkNode.children[0].text.text,
            "Our tools define our relationship with the world. Web browsers have framed our cognitive behavior to such an extent we don’t question it anymore. Can thinking be reduced to a search box with no memory or context? What is left of the thousands hours you spent on the web"
        )

        XCTAssertTrue(note.children[6].text.isEmpty)
    }

}

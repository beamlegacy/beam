import XCTest
import BeamCore
@testable import Beam

final class MarkdownExportTests: XCTestCase {

    func testEmptyNoteExport() throws {
        let note = try BeamNote(title: "An empty note")
        XCTAssert(note.isEntireNoteEmpty())
        let export = MarkdownExporter.export(of: note)
        XCTAssertTrue(export.contents.isEmpty)
    }

    func testSimpleNoteExport() throws {
        let note = try BeamNote(title: "Simple note")
        note.addChild(BeamElement("Some content"))

        let export = MarkdownExporter.export(of: note)
        XCTAssertFalse(export.contents.isEmpty)
        XCTAssertEqual(export.contents, "Some content  ")

        note.addChild(BeamElement(BeamText("Some text in bold", attributes: [.strong])))
        note.addChild(BeamElement(BeamText("Some text in italic", attributes: [.emphasis])))
        note.addChild(BeamElement(BeamText("Some strikethrough text", attributes: [.strikethrough])))
        note.addChild(BeamElement(BeamText("Some link", attributes: [.link("https://beamapp.co")])))

        let headingElement1 = BeamElement("Some big heading")
        headingElement1.kind = .heading(1)
        note.addChild(headingElement1)

        let headingElement2 = BeamElement("Some smaller heading")
        headingElement2.kind = .heading(2)
        note.addChild(headingElement2)

        let list = BeamElement("Some list")
        let element1 = BeamElement("Some element")
        let element2 = BeamElement("Some other element")
        let element3 = BeamElement("Some final element")

        let subElement1 = BeamElement("Some sub element")
        let subElement2 = BeamElement("Some other sub element")

        element2.addChild(subElement1)
        element2.addChild(subElement2)

        list.addChild(element1)
        list.addChild(element2)
        list.addChild(element3)

        note.addChild(list)

        let export2 = MarkdownExporter.export(of: note)
        XCTAssertFalse(export2.contents.isEmpty)
        XCTAssertEqual(
            export2.contents,
            """
            Some content  
            **Some text in bold**  
            *Some text in italic*  
            ~~Some strikethrough text~~  
            [Some link](https://beamapp.co)  

            # Some big heading


            ## Some smaller heading

            Some list

              * Some element
              * Some other element
                * Some sub element
                * Some other sub element
              * Some final element\n
            """
        )
    }

    func testComplexNoteExport() throws {
        OnboardingNoteCreator.shared.createOnboardingNotes()

        let note = try XCTUnwrap(BeamNote.fetch(title: "Capture"))

        let export = MarkdownExporter.export(of: note)
        XCTAssertFalse(export.contents.isEmpty)
        XCTAssertEqual(
            export.contents,
            """
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

            ## Images

              * ![cpt-0.jpg](Capture_cpt-0.jpg)

            <br>

            ## Videos

              * [https://www.youtube.com/watch?v=3fNf4eoj8jc](https://www.youtube.com/watch?v=3fNf4eoj8jc)

            <br>

            ## Tweets

              * [https://twitter.com/elonmusk/status/1483631831748685835](https://twitter.com/elonmusk/status/1483631831748685835)

            <br>
            And much more: Figma boards, Soundcloud, Spotify, Sketchfab...  
            <br>
            <br>
            """
        )
    }

}

//
//  Html2MdTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import  Nimble
import XCTest
import Foundation
import SwiftSoup

@testable import Beam
@testable import BeamCore

class Html2MdTests: XCTestCase {
    override func setUp() {
        super.setUp()

    }

    func test1() {
        let html = """
        <span>en orientation dans le cadre d'un processus d'orientation, par ...</span>
        <span>
            <span> </span>
            <a  href="https://fr.wikipedia.org/wiki/Test_(psychologie)">
                Wikipédia
            </a>
        </span>
        """

        let md = html2Md(url: URL(string: "http://test.com")!, html: html)
        //Logger.shared.logDebug("MD: \(md)")

        XCTAssertEqual(md, "en orientation dans le cadre d'un processus d'orientation, par ...    [Wikipédia](https://fr.wikipedia.org/wiki/Test_%28psychologie%29)")
    }
    
    func testHtml2TextForClustering() {
        let html = """
        <!DOCTYPE html>
        <html>
            <body>
                <p>This is a paragraph.</p>
                <p>This is another paragraph.</p>
            </body>
        </html>
        """
        guard let doc = try? SwiftSoup.parse(html) else { return }
        let txt = html2TextForClustering(doc: doc)

        expect(txt) == "This is another paragraph."

        // XCTAssertEqual(txt, "This is a paragraph.This is another paragraph.")
    }

    func testHtml2Text_FilterEmptyLines() throws {
        let html = "<p>paragraph1<br></p>\n    \n      <p>paragraph3</p>"

        let results: [BeamText] = html2Text(url: URL(string: "http://test.com")!, html: html)
        XCTAssertEqual(results.count, 2)
    }

    func testHtml2Text_ParagraphWithLineBreakChar() {
        let html = """
        <p>Lorem ipsum \n dolor sit amet \n consectetur</p>
        """

        let results: [BeamText] = html2Text(url: URL(string: "http://test.com")!, html: html)
        XCTAssertEqual(results.count, 1)
    }

    func testHtml2Text_SplitParagraphWithLinks() {
        let html = """
        <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
        """

        let results: [BeamText] = html2Text(url: URL(string: "http://test.com")!, html: html)
        XCTAssertEqual(results.count, 1)
    }

    func testHtml2Text_multipleParagraphsWithLinks() {
        let html = """
        <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
                <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
        """

        let results: [BeamText] = html2Text(url: URL(string: "http://test.com")!, html: html)
        XCTAssertEqual(results.count, 2)
    }
    
    func testHtml2Text_List() {
        let html = """
        <li><p>Lorem ipsum Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> consequuntur consequatur blanditiis!</p></li>
        <li><p>Lorem ipsum Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> consequuntur</p></li>
        """

        let results: [BeamText] = html2Text(url: URL(string: "http://test.com")!, html: html)
        XCTAssertEqual(results.count, 2)
    }

    func testHtml2Text_UL() {
        let html = """
        <ul>
        <li>Lorem ipsum</li>
        <li>Lorem ipsum</li>
        </ul>
        """

        let results: [BeamText] = html2Text(url: URL(string: "http://test.com")!, html: html)
        XCTAssertEqual(results.count, 2)
    }

    func testHtml2Text_Array() {
        let html = "<li><p>What sort of person will the use of this technology make of me?</p></li> <li><p>What habits will the use of this technology instill?</p></li> <li>   <p>How will the use of this technology affect my experience of time?</p> </li> <li>   <p>How will the use of this technology affect my experience of place?</p> </li> <li>   <p>     How will the use of this technology affect how&nbsp;I relate to other     people?   </p> </li> <li>   <p>     How will the use of this technology affect how I relate to the world around     me?   </p> </li> <li><p>What practices will the use of this technology cultivate?</p></li> <li><p>What practices will the use of this technology displace?</p></li> <li>   <p>What will the use of this technology encourage&nbsp;me to notice?</p> </li> <li>   <p>What will the use of this technology&nbsp;encourage me to ignore?</p> </li> <li>   <p>     What was required of other human beings so that I might be able to use this     technology?   </p> </li> <li>   <p>     What was required of other creatures so that I might be able to use this     technology?   </p> </li> <li>   <p>     What was required of the earth so that I might be able to use this     technology?   </p> </li> <li>   <p>     Does the use of this technology bring me joy? [N.B. This was years before I     even heard of Marie Kondo!]   </p> </li> <li><p>Does the use of this technology arouse anxiety?</p></li> <li><p>How does this technology empower me? At whose expense?</p></li> <li>   <p>     What feelings does the use of this technology generate in me toward others?   </p> </li> <li><p>Can I imagine living without this technology? Why, or why not?</p></li> <li><p>How does this technology encourage me to allocate my time?</p></li> <li>   <p>     Could the resources used&nbsp;to acquire and use this technology be better     deployed?   </p> </li> <li>   <p>     Does this technology automate or outsource labor or responsibilities that     are morally essential?   </p> </li> <li><p>What desires does the use of this technology generate?</p></li> <li><p>What desires does the use of this technology dissipate?</p></li> <li>   <p>     What possibilities for action does this technology present? Is it good that     these actions are now&nbsp;possible?   </p> </li> <li>   <p>     What possibilities for action does this technology foreclose?&nbsp;Is it     good that these actions are no longer possible?   </p> </li> <li>   <p>How does the use of this technology shape my vision of a good life?</p> </li> <li><p>What limits does the use of this technology impose upon me?</p></li> <li>   <p>What limits does my&nbsp;use of this technology impose upon others?</p> </li> <li>   <p>     What does my use of this technology require of others who would (or must)     interact with me?   </p> </li> <li>   <p>     What assumptions about the world does the use of this&nbsp;technology     tacitly encourage?   </p> </li> <li>   <p>     What knowledge has&nbsp;the use of this technology disclosed to me about     myself?   </p> </li> <li>   <p>     What knowledge has the use of this technology disclosed to me about others?     Is it good to have this&nbsp;knowledge?   </p> </li> <li>   <p>     What are&nbsp;the potential harms to myself, others, or the world that might     result from my use of this technology?   </p> </li> <li>   <p>     Upon what&nbsp;systems, technical or human, does&nbsp;my use of this     technology depend? Are these systems just?   </p> </li> <li>   <p>     Does my use of this technology encourage me to view others as a means to an     end?   </p> </li> <li><p>Does using this technology require me to think more or less?</p></li> <li>   <p>     What would the world be like if everyone used this technology exactly as I     use it?   </p> </li> <li>   <p>     What risks will&nbsp;my use of this technology entail for others? Have they     consented?   </p> </li> <li>   <p>     Can the consequences of my&nbsp;use of this technology be undone? Can I live     with those consequences?   </p> </li> <li>   <p>     Does my use of this technology make it easier to live as if I had no     responsibilities toward my neighbor?   </p> </li> <li>   <p>     Can I be held responsible for the actions which this technology empowers?     Would I feel better if I couldn’t?   </p> </li>"

        let resultText: [BeamText] = html2Text(url: URL(string: "https://www.wikipedia.org")!, html: html)
        XCTAssertEqual(resultText.count, 41)
    }

    func testHtml2Text_video() {
        let html = "<video src=\"video/video.mp4\" type=\"video/mp4\" controls=\"controls\">\n\tJe browser heeft geen ondersteuning voor video.\n</video>"
        let result: BeamText = html2Text(url: URL(string: "https://www.tutorialspoint.com/html_video_tag.htm")!, html: html)

        let expectedRange: BeamText.Range = BeamText.Range(string: "video/video.mp4", attributes: [.link("https://www.tutorialspoint.com/video/video.mp4")], position: 0)
        XCTAssertEqual(result.ranges[0], expectedRange)
        XCTAssertEqual(result.ranges.count, 1)
    }

    func testHtml2Text_videoWithSourceTag() {
        let html = "<video width=\"575\" height=\"300\" poster=\"images/placeholder.jpg\" controls=\"controls\" style=\"background-color:#000;\">\n\t<source src=\"video/video.webm\" type=\"video/webm\">\n\t<source src=\"video/video.mp4\" type=\"video/mp4\">\n\tJe browser heeft geen ondersteuning voor video.\n</video>"
        let result: BeamText = html2Text(url: URL(string: "https://www.tutorialspoint.com/html_video_tag.htm")!, html: html)

        let expectedRange: BeamText.Range = BeamText.Range(string: "video/video.mp4", attributes: [.link("https://www.tutorialspoint.com/video/video.mp4")], position: 0)
        XCTAssertEqual(result.ranges[0], expectedRange)
        XCTAssertEqual(result.ranges.count, 1)
    }

    func testHtml2Text_YouTubevideo() {
        let html = """
        <video tabindex="-1" class="video-stream html5-main-video" controlslist="nodownload" style="width: 878px; height: 494px; left: 0px; top: 0px;" src="blob:https://www.youtube.com/269afa34-170e-476e-9528-11bddf201561"></video>
        """

        let results: [BeamText] = html2Text(url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!, html: html)
        XCTAssertEqual(results.count, 1)
    }

    func testHtml2Text_iframe() {
        let html = """
        <iframe width="560" height="315" src="https://www.youtube.com/embed/dQw4w9WgXcQ" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
        """

        let results: [BeamText] = html2Text(url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!, html: html)
        XCTAssertEqual(results.count, 1)
    }

    func testHtml2Text_imageWithoutScheme() {
        let html = "<img alt=\"\" src=\"//i.imgur.com/someImage.png\">"

        let results: [BeamText] = html2Text(url: URL(string: "https://i.imgur.com")!, html: html)
        XCTAssertEqual(results.count, 1)
        let links = results[0].links
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first!, "https://i.imgur.com/someImage.png")
    }
}

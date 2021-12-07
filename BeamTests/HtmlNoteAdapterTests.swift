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

extension ElementKind {
    public var isImage: Bool {
        switch self {
        case .image:
            return true
        default:
            return false
        }
    }
}

class HtmlNoteAdapterTests: XCTestCase {
    var testFileStorage: FileStorageMock?
    var testDownloadManager: DownloadManagerMock?
    var htmlNoteAdapter: HtmlNoteAdapter!

    override func setUp() {
        super.setUp()
    }

    /// Setup the required mock classes
    /// - Parameter string: page url string
    func setupTestMocks(_ string: String) -> HtmlNoteAdapter {
        let url = URL(string: string)!
        testFileStorage = FileStorageMock()
        testDownloadManager = DownloadManagerMock()
        return HtmlNoteAdapter(url, testDownloadManager, testFileStorage)
    }

    func testConvertForClustering() {
        let html = """
        <!DOCTYPE html>
        <html>
            <body>
                <p>This is a paragraph.</p>
                <p>This is another paragraph.</p>
            </body>
        </html>
        """
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let txt = htmlNoteAdapter.convertForClustering(html: html)
        
        XCTAssertEqual(txt, ["This is a paragraph.", "This is another paragraph."])
    }
    
    func testBasicParagraph() throws {
        let html = "<p>paragraph1</p>"
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results[0].text.text, "paragraph1")
            XCTAssertEqual(results.count, 1)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFilterEmptyLines() throws {
        let html = "<p>paragraph1<br></p>\n    \n      <p>paragraph3</p>"
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 2)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testParagraphWithLineBreakChar() {
        let html = """
        <p>Lorem ipsum \n dolor sit amet \n consectetur</p>
        """
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSplitParagraphWithLinks() {
        let html = """
        <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
        """
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMultipleParagraphsWithLinks() {
        let html = """
        <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
                <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
        """
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 2)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testList() {
        let html = """
        <li><p>Lorem ipsum Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> consequuntur consequatur blanditiis!</p></li>
        <li><p>Lorem ipsum Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> consequuntur</p></li>
        """
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 2)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUL() {
        let html = """
        <ul>
        <li>Lorem ipsum</li>
        <li>Lorem ipsum</li>
        </ul>
        """
        let htmlNoteAdapter = self.setupTestMocks("http://test.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 2)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testArray() {
        let html = "<li><p>What sort of person will the use of this technology make of me?</p></li> <li><p>What habits will the use of this technology instill?</p></li> <li>   <p>How will the use of this technology affect my experience of time?</p> </li> <li>   <p>How will the use of this technology affect my experience of place?</p> </li> <li>   <p>     How will the use of this technology affect how&nbsp;I relate to other     people?   </p> </li> <li>   <p>     How will the use of this technology affect how I relate to the world around     me?   </p> </li> <li><p>What practices will the use of this technology cultivate?</p></li> <li><p>What practices will the use of this technology displace?</p></li> <li>   <p>What will the use of this technology encourage&nbsp;me to notice?</p> </li> <li>   <p>What will the use of this technology&nbsp;encourage me to ignore?</p> </li> <li>   <p>     What was required of other human beings so that I might be able to use this     technology?   </p> </li> <li>   <p>     What was required of other creatures so that I might be able to use this     technology?   </p> </li> <li>   <p>     What was required of the earth so that I might be able to use this     technology?   </p> </li> <li>   <p>     Does the use of this technology bring me joy? [N.B. This was years before I     even heard of Marie Kondo!]   </p> </li> <li><p>Does the use of this technology arouse anxiety?</p></li> <li><p>How does this technology empower me? At whose expense?</p></li> <li>   <p>     What feelings does the use of this technology generate in me toward others?   </p> </li> <li><p>Can I imagine living without this technology? Why, or why not?</p></li> <li><p>How does this technology encourage me to allocate my time?</p></li> <li>   <p>     Could the resources used&nbsp;to acquire and use this technology be better     deployed?   </p> </li> <li>   <p>     Does this technology automate or outsource labor or responsibilities that     are morally essential?   </p> </li> <li><p>What desires does the use of this technology generate?</p></li> <li><p>What desires does the use of this technology dissipate?</p></li> <li>   <p>     What possibilities for action does this technology present? Is it good that     these actions are now&nbsp;possible?   </p> </li> <li>   <p>     What possibilities for action does this technology foreclose?&nbsp;Is it     good that these actions are no longer possible?   </p> </li> <li>   <p>How does the use of this technology shape my vision of a good life?</p> </li> <li><p>What limits does the use of this technology impose upon me?</p></li> <li>   <p>What limits does my&nbsp;use of this technology impose upon others?</p> </li> <li>   <p>     What does my use of this technology require of others who would (or must)     interact with me?   </p> </li> <li>   <p>     What assumptions about the world does the use of this&nbsp;technology     tacitly encourage?   </p> </li> <li>   <p>     What knowledge has&nbsp;the use of this technology disclosed to me about     myself?   </p> </li> <li>   <p>     What knowledge has the use of this technology disclosed to me about others?     Is it good to have this&nbsp;knowledge?   </p> </li> <li>   <p>     What are&nbsp;the potential harms to myself, others, or the world that might     result from my use of this technology?   </p> </li> <li>   <p>     Upon what&nbsp;systems, technical or human, does&nbsp;my use of this     technology depend? Are these systems just?   </p> </li> <li>   <p>     Does my use of this technology encourage me to view others as a means to an     end?   </p> </li> <li><p>Does using this technology require me to think more or less?</p></li> <li>   <p>     What would the world be like if everyone used this technology exactly as I     use it?   </p> </li> <li>   <p>     What risks will&nbsp;my use of this technology entail for others? Have they     consented?   </p> </li> <li>   <p>     Can the consequences of my&nbsp;use of this technology be undone? Can I live     with those consequences?   </p> </li> <li>   <p>     Does my use of this technology make it easier to live as if I had no     responsibilities toward my neighbor?   </p> </li> <li>   <p>     Can I be held responsible for the actions which this technology empowers?     Would I feel better if I couldn’t?   </p> </li>"
        let htmlNoteAdapter = self.setupTestMocks("https://www.wikipedia.org")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 41)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testvideo() {
        let html = "<video src=\"video/video.mp4\" type=\"video/mp4\" controls=\"controls\">\n\tJe browser heeft geen ondersteuning voor video.\n</video>"
        let htmlNoteAdapter = self.setupTestMocks("https://www.tutorialspoint.com/html_video_tag.htm")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let firstChild = results.first {
                let expectedRange: BeamText.Range = BeamText.Range(string: "https://www.tutorialspoint.com/video/video.mp4", attributes: [.link("https://www.tutorialspoint.com/video/video.mp4")], position: 0)
                XCTAssertEqual(firstChild.text.ranges[0], expectedRange)
                XCTAssertEqual(firstChild.text.ranges.count, 1)
            } else {
                XCTFail("expect atleast one child")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testvideoWithSourceChild_Multiple() {
        let html = """
        <video width="575" height="300" poster="images/placeholder.jpg" controls="controls" style="background-color:#000;">\n\t
            <source src="video/video.webm" type="video/webm">\n\t
            <source src="video/video.mp4" type="video/mp4">\n\tJe browser heeft geen ondersteuning voor video.\n
        </video>
        """
        let htmlNoteAdapter = self.setupTestMocks("https://www.tutorialspoint.com/html_video_tag.htm")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let firstChild = results.first {
                let expectedRange: BeamText.Range = BeamText.Range(string: "https://www.tutorialspoint.com/video/video.mp4", attributes: [.link("https://www.tutorialspoint.com/video/video.mp4")], position: 0)
                XCTAssertEqual(firstChild.text.ranges[0], expectedRange)
                XCTAssertEqual(firstChild.text.ranges.count, 1)
            } else {
                XCTFail("expect atleast one child")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testvideoWithSourceChild_onlyMov() {
        let html = """
            <video controls="" loop="" id="video" width="200">
            <source src="video.mov" type="video/mp4">
            </video>
        """
        let htmlNoteAdapter = self.setupTestMocks("file:///Users/andrii/Documents/dev/beam/DerivedData/Beam/Build/Products/Test/Beam.app/Contents/Resources/UITests-Media.html")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            if let firstChild = results.first {
                let videoUrl = "file:///Users/andrii/Documents/dev/beam/DerivedData/Beam/Build/Products/Test/Beam.app/Contents/Resources/video.mov"
                let expectedRange: BeamText.Range = BeamText.Range(string: videoUrl, attributes: [.link(videoUrl)], position: 0)
                XCTAssertEqual(firstChild.text.ranges[0], expectedRange)
                XCTAssertEqual(firstChild.text.ranges.count, 1)
            } else {
                XCTFail("expect atleast one child")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testvideoWithSourceTag() {
        let html = "<video width=\"575\" height=\"300\" poster=\"images/placeholder.jpg\" controls=\"controls\" style=\"background-color:#000;\">\n\t<source src=\"video/video.webm\" type=\"video/webm\">\n\t<source src=\"video/video.mp4\" type=\"video/mp4\">\n\tJe browser heeft geen ondersteuning voor video.\n</video>"
        let htmlNoteAdapter = self.setupTestMocks("https://www.tutorialspoint.com/html_video_tag.htm")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let firstChild = results.first {
                let videoUrl = "https://www.tutorialspoint.com/video/video.mp4"
                let expectedRange: BeamText.Range = BeamText.Range(string: videoUrl, attributes: [.link(videoUrl)], position: 0)
                XCTAssertEqual(firstChild.text.ranges[0], expectedRange)
                XCTAssertEqual(firstChild.text.ranges.count, 1)
            } else {
                XCTFail("expect atleast one child")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testYouTubevideo() {
        let html = """
        <video tabindex="-1" class="video-stream html5-main-video" controlslist="nodownload" style="width: 878px; height: 494px; left: 0px; top: 0px;" src="blob:https://www.youtube.com/269afa34-170e-476e-9528-11bddf201561"></video>
        """
        let urlString = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let htmlNoteAdapter = self.setupTestMocks(urlString)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let embedElement = results.first,
               let url = URL(string: urlString) {
                XCTAssertEqual(embedElement.kind, .embed(url, origin: SourceMetadata(origin: .remote(url)), displayRatio: nil))
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testiframe() {
        let html = """
        <iframe width="560" height="315" src="https://www.youtube.com/embed/dQw4w9WgXcQ" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
        """
        let htmlNoteAdapter = self.setupTestMocks("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let embedElement = results.first,
               let url = URL(string: "https://www.youtube.com/embed/dQw4w9WgXcQ") {
                XCTAssertEqual(embedElement.kind, .embed(url, origin: SourceMetadata(origin: .remote(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)), displayRatio: nil))
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testYouTubeIframe() {
        let html = "<iframe width=\"728\" height=\"410\" src=\"https://www.youtube.com/embed/dQw4w9WgXcQ\" title=\"YouTube video player\" frameborder=\"0\" allow=\"accelerometer; autoplay;clipboard-write;encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>"
        let htmlNoteAdapter = self.setupTestMocks("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let embedElement = results.first,
               let url = URL(string: "https://www.youtube.com/embed/dQw4w9WgXcQ") {
                XCTAssertEqual(embedElement.kind, .embed(url, origin: SourceMetadata(origin: .remote(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)), displayRatio: nil))
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testImageNotEndingOnImageExtension() {
        let html = "<img src=\"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRRaAkltuaC5Ch8zLuS-s9wsNX92XEwVNhl3OGvWGKGShGlZeKb&amp;usqp=CAU\">"
        let url = "https://www.google.com/search?q=everest&client=safari&hl=en&tbm=isch&source=lnms&sa=X&ved=2ahUKEwii5emWu4PzAhWdQ_EDHYn-CVUQ_AUoAXoECAEQAw&biw=799&bih=574&dpr=2"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRRaAkltuaC5Ch8zLuS-s9wsNX92XEwVNhl3OGvWGKGShGlZeKb&usqp=CAU"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testImageWithoutScheme() {
        let html = "<img alt=\"\" src=\"//i.imgur.com/someImage.png\">"
        let url = "https://i.imgur.com"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "https://i.imgur.com/someImage.png"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testImageWithLocalFileScheme() {
        let html = "<img src=\"file:///Users/stefkors/Library/Developer/Xcode/DerivedData/Beam-aorwqrkozzstkmcrhprefoujlbhw/Build/Products/Debug/Beam.app/Contents/Resources/logo.png\">"
        let url = "file:///Users/stefkors/Library/Developer/Xcode/DerivedData/Beam-aorwqrkozzstkmcrhprefoujlbhw/Build/Products/Debug/Beam.app/Contents/Resources/UITests-7.html"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "file:///Users/stefkors/Library/Developer/Xcode/DerivedData/Beam-aorwqrkozzstkmcrhprefoujlbhw/Build/Products/Debug/Beam.app/Contents/Resources/logo.png"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testImage_srcset() throws {
        let html = """
            <img srcset="https://cdn.vox-cdn.com/thumbor/fkUSjhcz8i5Fc7BaSKlAeQK5sII=/0x0:2040x1360/320x213/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 320w, https://cdn.vox-cdn.com/thumbor/Z08vUctDdB7hR22UHQ134sPSU38=/0x0:2040x1360/620x413/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 620w, https://cdn.vox-cdn.com/thumbor/vg6dXHVGRUgfW0LzAOnqIYRkkqs=/0x0:2040x1360/920x613/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 920w, https://cdn.vox-cdn.com/thumbor/z_I2AchFEUP_m29s9pAmwVU3e10=/0x0:2040x1360/1220x813/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 1220w, https://cdn.vox-cdn.com/thumbor/vJ5jXL0n4PDWRyqZArrxgp02cU8=/0x0:2040x1360/1520x1013/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 1520w, https://cdn.vox-cdn.com/thumbor/9xQkpT5PEHjgPykg92aW9lcssYE=/0x0:2040x1360/1820x1213/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 1820w, https://cdn.vox-cdn.com/thumbor/NTw9Gu8yVby6PYkP9EXPVSxa9U0=/0x0:2040x1360/2120x1413/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 2120w, https://cdn.vox-cdn.com/thumbor/rM2KvNsiMD7kEpVqn8aFQJjc574=/0x0:2040x1360/2420x1613/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 2420w" sizes="(min-width: 1221px) 846px, (min-width: 880px) calc(100vw - 334px), 100vw" alt="" data-upload-width="2040" src="https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg">
            """
        let url = "https://www.theverge.com/22639309/gmail-google-chat-rooms-how-to-android-ios"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testImageUrl_dontMarkdownize() throws {
        let html = "<img src=\"https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg\">"
        
        let url = "https://www.theverge.com/22639309/gmail-google-chat-rooms-how-to-android-ios"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
                
                let escapedMarkdownImageUrl = "https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal%28857x517:1183x843%29/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg"
                XCTAssertNotEqual(downloadEvent, "downloaded \(escapedMarkdownImageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testImageUrl_relative() throws {
        let html = "<img src=\"beam-logo-test.png\">"
        let url = "https://www.theverge.com"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "https://www.theverge.com/beam-logo-test.png"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }

            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testImageUrl_relativeLocalHtmlPage() throws {
        let html = "<img src=\"beam-logo-test.png\">"
        let url = "file:///Users/stefkors/Library/Developer/Xcode/DerivedData/Beam-aorwqrkozzstkmcrhprefoujlbhw/Build/Products/Debug/Beam.app/Contents/Resources/UITests-4.html"
        let htmlNoteAdapter = self.setupTestMocks(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let downloadEvent = testDownloadManager.events.first {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                let imageUrl = "file:///Users/stefkors/Library/Developer/Xcode/DerivedData/Beam-aorwqrkozzstkmcrhprefoujlbhw/Build/Products/Debug/Beam.app/Contents/Resources/beam-logo-test.png"
                let headers = ["Referer": url]
                XCTAssertEqual(downloadEvent, "downloaded \(imageUrl) with headers \(headers)")
            } else {
                XCTFail("expected atleast one element")
            }

            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testImageBase64NoFileStorage() throws {
        let html = "<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\" />"
        let url = URL(string: "https://www.w3docs.com/snippets/html/how-to-display-base64-images-in-html.html")!
        // Init HtmlNoteAdapter without fileStorage or DownloadManager
        let htmlNoteAdapter = HtmlNoteAdapter(url)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 0)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testImageBase64WithFileStorage() throws {
        let html = "<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\" />"
        let htmlNoteAdapter = self.setupTestMocks("https://www.theverge.com/22639309/gmail-google-chat-rooms-how-to-android-ios")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1)
            if let element = results.first,
               let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage {
                XCTAssertTrue(element.kind.isImage)
                XCTAssertEqual(testFileStorage.events.count, 1)
                // Expect no file download for base64 images
                XCTAssertEqual(testDownloadManager.events.count, 0)
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testImageWithEmptySrc() throws {
        let html = "<img src=\"\" />"
        let htmlNoteAdapter = self.setupTestMocks("https://www.w3docs.com/snippets/html/how-to-display-base64-images-in-html.html")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage {
                XCTAssertEqual(results.count, 0)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
            } else {
                XCTFail("expected atleast one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
}

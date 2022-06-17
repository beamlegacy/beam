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
        Configuration.setAPIEndPointsToStaging()
    }

    override class func tearDown() {
        Configuration.reset()
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
                XCTFail("expect at least one child")
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
                XCTFail("expect at least one child")
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
                XCTFail("expect at least one child")
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
                XCTFail("expect at least one child")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testYouTubevideo() throws {
        let html = """
        <video tabindex="-1" class="video-stream html5-main-video" controlslist="nodownload" style="width: 878px; height: 494px; left: 0px; top: 0px;" src="blob:https://www.youtube.com/269afa34-170e-476e-9528-11bddf201561"></video>
        """
        let urlString = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let htmlNoteAdapter = self.setupTestMocks(urlString)
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html, completion: { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1, "expected one result, recieved \(results) instead")
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertTrue(firstEl.kind.isEmbed, "expected kind to be embed, recieved \(firstEl.kind) instead")
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
                expectation.fulfill()
            } else {
                XCTFail("expected at least one element")
            }
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
                XCTAssertEqual(embedElement.kind, .embed(url, origin: SourceMetadata(origin: .remote(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)), displayInfos: MediaDisplayInfos()))
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
                XCTAssertEqual(embedElement.kind, .embed(url, origin: SourceMetadata(origin: .remote(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)), displayInfos: MediaDisplayInfos()))
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
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
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    func testPDFlink() {
        let html = "<a href=\"https://joe.cat/images/papers/tabs.pdf\">https://joe.cat/images/papers/tabs.pdf</a>"

        let htmlNoteAdapter = self.setupTestMocks("https://joe.cat/images/papers/tabs.pdf")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage {
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testBRelement() {
        let html = """
                    <p class="secondary above-default-only">If you can wait and not be tired by waiting,<br>Or, being lied about, don’t deal in lies,<br>Or, being hated, don’t give way to hating,<br>And yet don’t look too good, nor talk too wise;<br></p>
                    """
        let htmlNoteAdapter = setupTestMocks("https://hellobeam.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)

                XCTAssertEqual(firstEl.text.text, "If you can wait and not be tired by waiting, Or, being lied about, don’t deal in lies, Or, being hated, don’t give way to hating, And yet don’t look too good, nor talk too wise;")
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testSoundCloudEmbedElement() {
        let html = """
            <a href="https://w.soundcloud.com/player/?visual=true&url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F293&show_artwork=true">retweets</a>
        """
        let htmlNoteAdapter = setupTestMocks("https://public.beamapp.co/beam/note")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
                XCTAssertTrue(firstEl.kind.isEmbed)
                if case let .embed(url, _, _) = firstEl.kind {
                    XCTAssertEqual(url.absoluteString, "https://api.soundcloud.com/tracks/293&show_artwork=true")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testLimitDuplicateEmbedElements() {
        let html = """
            <a href="/myhistorytales/status/1500423493829074945/retweets">retweets</a>
            <a href="/myhistorytales/status/1500423493829074945/likes">likes</a>
            <a href="/myhistorytales/status/1500423493829074945">open tweet</a>
        """
        let htmlNoteAdapter = setupTestMocks("https://twitter.com/myhistorytales/status/1500423493829074945")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
                XCTAssertTrue(firstEl.kind.isEmbed)
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testLimitDuplicateEmbedElementsMixedContent() {
        let html = """
            <a href="/myhistorytales/status/1500423493829074945/retweets">retweets</a>
            <a href="/myhistorytales/status/1500423493829074945/likes">likes</a>
            <b>bold text</b>
            <a href="/myhistorytales/status/1500423493829074945">open tweet</a>
        """
        let htmlNoteAdapter = setupTestMocks("https://twitter.com/myhistorytales/status/1500423493829074945")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertEqual(results.count, 2)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
                XCTAssertTrue(firstEl.kind.isEmbed)
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testTwitterHtml() {
        let html = """
        <a href="https://twitter.com/getonbeam/status/1512059116482670597">
            https://twitter.com/getonbeam/status/1512059116482670597
        </a>
        """
        let htmlNoteAdapter = setupTestMocks("https://www.twitter.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1, "expected one result, recieved \(results) instead")
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertTrue(firstEl.kind.isEmbed, "expected kind to be embed, recieved \(firstEl.kind) instead")
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 0)
                expectation.fulfill()
            } else {
                XCTFail("expected at least one element")
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testRedditHtml() {
        // Link to embeddable element containing an image
        let html = """
        <a href="https://www.reddit.com/r/MotivationalPics/comments/ud18lk/get_up_and_try/">
            <img alt="Post image" class="_2_tDEnGMLxpM6uOa2kaDB3 ImageBox-image media-element _1XWObl-3b9tPy64oaG6fax" src="https://external-preview.redd.it/fz9RoZX4AMY1XcSaXJ7UjleSiSLxCCPVbicY1DaSC8w.jpg?auto=webp&amp;s=affc958af9879e10c655c85f534475702bb06a7e" style="max-height: 512px;">
        </a>
        """
        let htmlNoteAdapter = setupTestMocks("https://www.reddit.com")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1, "expected one result, recieved \(results) instead")
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertTrue(firstEl.kind.isImage, "expected kind to be image, recieved \(firstEl.kind) instead")
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 1)
                XCTAssertEqual(testFileStorage.events.count, 1)
                expectation.fulfill()
            } else {
                XCTFail("expected at least one element")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testPartialSVGHtml() {
        let html = "<g class=\"style-scope yt-icon\">\n <path d=\"M12,3c3.31,0,6,2.69,6,6c0,3.83-4.25,9.36-6,11.47C9.82,17.86,6,12.54,6,9C6,5.69,8.69,3,12,3 M12,2C8.13,2,5,5.13,5,9 c0,5.25,7,13,7,13s7-7.75,7-13C19,5.13,15.87,2,12,2L12,2z M12,7c1.1,0,2,0.9,2,2s-0.9,2-2,2s-2-0.9-2-2S10.9,7,12,7 M12,6 c-1.66,0-3,1.34-3,3s1.34,3,3,3s3-1.34,3-3S13.66,6,12,6L12,6z\" class=\"style-scope yt-icon\"></path>\n</g>"
        let htmlNoteAdapter = setupTestMocks("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 0, "expected one result, recieved \(results) instead")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testSVGviewBoxHtml() {
        let html = """
        <svg viewBox="0 0 24 24" preserveAspectRatio="xMidYMid meet" focusable="false" style="pointer-events: none; display: block; width: 100%; height: 100%;" class="style-scope yt-icon"><g class="style-scope yt-icon"><path d="M12.7,12l6.6,6.6l-0.7,0.7L12,12.7l-6.6,6.6l-0.7-0.7l6.6-6.6L4.6,5.4l0.7-0.7l6.6,6.6l6.6-6.6l0.7,0.7L12.7,12z" class="style-scope yt-icon"></path></g></svg>
        """
        let htmlNoteAdapter = setupTestMocks("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1, "expected one result, recieved \(results) instead")
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertTrue(firstEl.kind.isImage, "expected kind to be image, recieved \(firstEl.kind) instead")
                if case let .image(uuid, origin, displayInfos) = firstEl.kind {
                    XCTAssertNotNil(uuid)
                    XCTAssertNotNil(origin)
                    XCTAssertEqual(displayInfos, MediaDisplayInfos(height: 24, width: 24, displayRatio: nil))
                }
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 1)
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }


    func testSVGWidthHeightHtml() {
        let html = """
        <svg width="24" height="18" xmlns="http://www.w3.org/2000/svg" class="sc-144c310-0 CFcff"><path d="M24 14.52c0 1.8-1.45 3.25-3.25 3.25-.57 0-2 0-5.94.03l-5.95.04A3.25 3.25 0 018 11.47a3.25 3.25 0 014-2.93 5.07 5.07 0 019.7 2.87c1.33.4 2.3 1.65 2.3 3.11zm-3.28-1.74a.75.75 0 01-.7-1.04 3.57 3.57 0 10-6.8-2.05c-.1.5-.67.76-1.11.5a1.72 1.72 0 00-.88-.24 1.75 1.75 0 00-1.72 2.03.75.75 0 01-.7.87 1.74 1.74 0 00.05 3.49l5.94-.04 5.95-.03a1.75 1.75 0 00.03-3.5h-.06zm-9.4-7.41a.75.75 0 11-.72 1.31 2.86 2.86 0 00-4.07 3.5.75.75 0 11-1.41.5 4.37 4.37 0 016.2-5.31zm-1.38-3a.75.75 0 11-1.5 0V.75a.75.75 0 011.5 0v1.62zM.75 9.94a.75.75 0 010-1.5h1.62a.75.75 0 110 1.5H.75zm1.94-6.19A.75.75 0 113.75 2.7L4.9 3.84a.75.75 0 01-1.07 1.05L2.7 3.75z" fill="currentColor"></path></svg>
        """
        let htmlNoteAdapter = setupTestMocks("https://www.nos.nl")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1, "expected one result, recieved \(results) instead")
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertTrue(firstEl.kind.isImage, "expected kind to be image, recieved \(firstEl.kind) instead")
                if case let .image(uuid, origin, displayInfos) = firstEl.kind {
                    XCTAssertNotNil(uuid)
                    XCTAssertNotNil(origin)
                    XCTAssertEqual(displayInfos, MediaDisplayInfos(height: 18, width: 24, displayRatio: nil))
                }
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 1)
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testSVGWidthHeightPixelsHtml() {
        let html = """
        <svg width="24px" height="18px" xmlns="http://www.w3.org/2000/svg" class="sc-144c310-0 CFcff"><path d="M24 14.52c0 1.8-1.45 3.25-3.25 3.25-.57 0-2 0-5.94.03l-5.95.04A3.25 3.25 0 018 11.47a3.25 3.25 0 014-2.93 5.07 5.07 0 019.7 2.87c1.33.4 2.3 1.65 2.3 3.11zm-3.28-1.74a.75.75 0 01-.7-1.04 3.57 3.57 0 10-6.8-2.05c-.1.5-.67.76-1.11.5a1.72 1.72 0 00-.88-.24 1.75 1.75 0 00-1.72 2.03.75.75 0 01-.7.87 1.74 1.74 0 00.05 3.49l5.94-.04 5.95-.03a1.75 1.75 0 00.03-3.5h-.06zm-9.4-7.41a.75.75 0 11-.72 1.31 2.86 2.86 0 00-4.07 3.5.75.75 0 11-1.41.5 4.37 4.37 0 016.2-5.31zm-1.38-3a.75.75 0 11-1.5 0V.75a.75.75 0 011.5 0v1.62zM.75 9.94a.75.75 0 010-1.5h1.62a.75.75 0 110 1.5H.75zm1.94-6.19A.75.75 0 113.75 2.7L4.9 3.84a.75.75 0 01-1.07 1.05L2.7 3.75z" fill="currentColor"></path></svg>
        """
        let htmlNoteAdapter = setupTestMocks("https://www.nos.nl")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 1, "expected one result, recieved \(results) instead")
            if let testDownloadManager = self.testDownloadManager,
               let testFileStorage = self.testFileStorage,
               let firstEl = results.first {
                XCTAssertTrue(firstEl.kind.isImage, "expected kind to be image, recieved \(firstEl.kind) instead")
                if case let .image(uuid, origin, displayInfos) = firstEl.kind {
                    XCTAssertNotNil(uuid)
                    XCTAssertNotNil(origin)
                    XCTAssertEqual(displayInfos, MediaDisplayInfos(height: 18, width: 24, displayRatio: nil))
                }
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(testDownloadManager.events.count, 0)
                XCTAssertEqual(testFileStorage.events.count, 1)
            } else {
                XCTFail("expected at least one element")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }


    func testSVGNoSizeHtml() {
        let html = """
        <svg preserveAspectRatio="xMidYMid meet" focusable="false" style="pointer-events: none; display: block; width: 100%; height: 100%;" class="style-scope yt-icon"><g class="style-scope yt-icon"><path d="M12.7,12l6.6,6.6l-0.7,0.7L12,12.7l-6.6,6.6l-0.7-0.7l6.6-6.6L4.6,5.4l0.7-0.7l6.6,6.6l6.6-6.6l0.7,0.7L12.7,12z" class="style-scope yt-icon"></path></g></svg>
        """
        let htmlNoteAdapter = setupTestMocks("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let expectation = XCTestExpectation(description: "convert html to BeamElements")
        htmlNoteAdapter.convert(html: html) { (results: [BeamElement]) in
            XCTAssertEqual(results.count, 0, "expected zero results, recieved \(results) instead")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

}

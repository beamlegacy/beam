import XCTest
import BeamCore
import Combine
@testable import Beam

final class ContextMenuMessageHandlerPayloadTests: XCTestCase {

    func testPageInvocationPayload() throws {
        let href = "https://www.google.com/search?q=daft%20punk"
        let messageBody: Any = [
            "href": href,
            "invocations": 1,
            "parameters": [:]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .page(let payloadHref) = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertTrue(payload.shouldBuildCustomMenu)
        XCTAssertEqual(payloadHref, href)
        XCTAssertEqual(payload.linkHrefURL?.absoluteString, href)
        XCTAssertNil(payload.contents)
        XCTAssertNil(payload.imageSrcURL)
    }

    func testTextSelectionInvocationPayload() throws {
        let href = "https://www.google.com/search?q=daft%20punk"
        let contents = "groupe de musique"
        let messageBody: Any = [
            "href": href,
            "invocations": 2,
            "parameters": ["contents": contents]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .textSelection(let payloadContents) = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertTrue(payload.shouldBuildCustomMenu)
        XCTAssertEqual(payloadContents, contents)
        XCTAssertEqual(payload.contents, contents)
        XCTAssertNil(payload.imageSrcURL)
        XCTAssertNil(payload.linkHrefURL)
    }

    func testLinkInvocationPayload() throws {
        let href = "https://www.google.com/search?q=daft%20punk"
        let targetHref = """
        https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwj43-qlk6b6AhWr8IUKHY8gATQQFnoECAkQAQ&url=https%3A%2F%2Ffr.wikipedia.org%2Fwiki%2FDaft_Punk&usg=AOvVaw2QfHD3iG08a2XyREooowur
        """
        let messageBody: Any = [
            "href": href,
            "invocations": 4,
            "parameters": ["href": targetHref]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .link(let payloadHref) = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertTrue(payload.shouldBuildCustomMenu)
        XCTAssertEqual(payloadHref, targetHref)
        XCTAssertEqual(payload.linkHrefURL?.absoluteString, targetHref)
        XCTAssertNil(payload.imageSrcURL)
        XCTAssertNil(payload.contents)
    }

    func testImageInvocationPayload() throws {
        let href = "https://www.google.com/search?q=shib"
        let src = "http://www.crypto-news-flash.com/wp-content/uploads/2021/11/Shiba.jpeg"
        let messageBody: Any = [
            "href": href,
            "invocations": 8,
            "parameters": ["src": src]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .image(let payloadSrc) = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertTrue(payload.shouldBuildCustomMenu)
        XCTAssertEqual(payloadSrc, src)
        XCTAssertEqual(payload.imageSrcURL?.absoluteString, payloadSrc)
        XCTAssertNil(payload.linkHrefURL)
        XCTAssertNil(payload.contents)
    }

    func testIgnoredInvocationPayload() throws {
        let href = "https://www.google.com/search?q=daft%20punk"
        let messageBody: Any = [
            "href": href,
            "invocations": 16,
            "parameters": [:]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .ignored = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertFalse(payload.shouldBuildCustomMenu)
        XCTAssertNil(payload.contents)
        XCTAssertNil(payload.linkHrefURL)
        XCTAssertNil(payload.imageSrcURL)
    }

    func testMultipleInvocationsPayload() throws {
        let href = "https://fr.wikipedia.org/wiki/Daft_Punk"
        let targetHref = "https://commons.wikimedia.org/wiki/File:Daftpunklapremiere2010.jpg?uselang=fr"
        let src = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Daftpunklapremiere2010.jpg/260px-Daftpunklapremiere2010.jpg"
        let messageBody: Any = [
            "href": href,
            "invocations": 12,
            "parameters": [
                "href" : targetHref,
                "src" : src
            ]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .multiple(let multipleItems) = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertEqual(multipleItems.count, 2)
        XCTAssertTrue(multipleItems.contains(where: { if case .link = $0 { return true } else { return false } }))
        XCTAssertTrue(multipleItems.contains(where: { if case .image = $0 { return true } else { return false } }))
        XCTAssertEqual(payload.imageSrcURL?.absoluteString, src)
        XCTAssertEqual(payload.linkHrefURL?.absoluteString, targetHref)
    }

    func testLinkPercentEncodingInvocationPayload() throws {
        let href = "https://www.cdiscount.com/search/10/brosse+a+dent.html#_his_"
        let targetHref = """
        https://www.cdiscount.com/electromenager/sante-minceur/brosse-a-dents-electrique-fairywill-rechargeable-b/f-110590501-fai0192802942012.html?idOffre=445251214#mpos=0|mp&sw=373007f994610a9d40a9b148599480aacd8fbd82a4936497ee231b4c2bd9dbb93d2eefd554cf4cc47ded058fb6e6486d1874977153b55d13ef305bad4606bcd38d0a29f7ed6ce7049a4533995090ffb2c84822dbbf255c1f94db8b299d059923befc80dda94cab8bd110beb11078c657ec4a92fe8899a37610fa02d412fd414e
        """
        let contents = "Brosse à dents électrique Fairywill Rechargeable brosse à dents sonic de voyage avec étui de voyage et 10 tête de brosse à dents"
        let messageBody: Any = [
            "href": href,
            "invocations": 6,
            "parameters": [
                "href" : targetHref,
                "contents" : contents
            ]
        ]
        let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
        guard case .multiple(let multipleItems) = payload else {
            XCTFail("Invalid parsed ContextMenuMessageHandlerPayload"); return
        }
        XCTAssertEqual(multipleItems.count, 2)
        XCTAssertTrue(multipleItems.contains(where: { if case .link = $0 { return true } else { return false } }))
        XCTAssertTrue(multipleItems.contains(where: { if case .textSelection = $0 { return true } else { return false } }))
        XCTAssertEqual(payload.contents, contents)
        // linkHrefURL should have been percent encoded
        XCTAssertEqual(payload.linkHrefURL?.absoluteString.removingPercentEncoding, targetHref)
        XCTAssertNil(payload.imageSrcURL)
    }

}

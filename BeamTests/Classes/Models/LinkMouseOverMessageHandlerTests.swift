import XCTest
@testable import Beam

class LinkMouseOverMessageHandlerTests: XCTestCase {

    private var messageHandler: LinkMouseOverMessageHandler!
    private var webPage: TestWebPage!
    private var browserTabConfiguration: BrowserTabConfiguration!

    override func setUp() {
        webPage = TestWebPage(
            browsingScorer: nil,
            passwordOverlayController: nil,
            pns: nil,
            fileStorage: nil,
            downloadManager: nil,
            navigationController: nil
        )

        browserTabConfiguration = BrowserTabConfiguration()
        messageHandler = LinkMouseOverMessageHandler(config: browserTabConfiguration)
    }

    func testMouseOverLink() {
        let body = [
            "url": "https://rickymartin.com/uno/dos/tres",
            "target": ""
        ]

        messageHandler.onMessage(messageName: "linkMouseOver", messageBody: body, from: webPage, frameInfo: nil)

        XCTAssertEqual(
            webPage.mouseHoveringLocation,
            .link(
                url: URL(string: "https://rickymartin.com/uno/dos/tres")!,
                opensInNewTab: false
            )
        )
    }

    func testMouseOverTargetBlankLink() {
        let body = [
            "url": "https://rickymartin.com/uno/dos/tres",
            "target": "_blank"
        ]

        messageHandler.onMessage(messageName: "linkMouseOver", messageBody: body, from: webPage, frameInfo: nil)

        XCTAssertEqual(
            webPage.mouseHoveringLocation,
            .link(
                url: URL(string: "https://rickymartin.com/uno/dos/tres")!,
                opensInNewTab: true
            )
        )
    }

    func testMouseOut() {
        messageHandler.onMessage(messageName: "linkMouseOver", messageBody: [], from: webPage, frameInfo: nil)

        XCTAssertEqual(webPage.mouseHoveringLocation, .none)
    }

}

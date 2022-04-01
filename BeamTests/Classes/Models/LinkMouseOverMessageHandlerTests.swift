import XCTest
@testable import Beam

class LinkMouseOverMessageHandlerTests: XCTestCase {

    private var messageHandler: LinkMouseOverMessageHandler!
    private var webPage: TestWebPage!
    private var browserTabConfiguration: BeamWebViewConfigurationBase!

    override func setUp() {
        webPage = TestWebPage(
            browsingScorer: nil,
            passwordOverlayController: nil,
            pns: nil,
            fileStorage: nil,
            downloadManager: nil,
            navigationController: nil
        )

        messageHandler = LinkMouseOverMessageHandler()
        browserTabConfiguration = BeamWebViewConfigurationBase(handlers: [messageHandler])
    }

    func testMouseOverLink() {
        let body = [
            "url": "https://rickymartin.com/uno/dos/tres",
            "target": ""
        ]

        messageHandler.onMessage(
            messageName: LinkMouseOverMessage.LinkMouseOver_linkMouseOver.rawValue,
            messageBody:
                body, from:
                webPage, frameInfo: nil
        )

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

        messageHandler.onMessage(
            messageName: LinkMouseOverMessage.LinkMouseOver_linkMouseOver.rawValue,
            messageBody:
                body, from:
                webPage, frameInfo: nil
        )

        XCTAssertEqual(
            webPage.mouseHoveringLocation,
            .link(
                url: URL(string: "https://rickymartin.com/uno/dos/tres")!,
                opensInNewTab: true
            )
        )
    }

    func testMouseOut() {
        messageHandler.onMessage(
            messageName: LinkMouseOverMessage.LinkMouseOver_linkMouseOver.rawValue,
            messageBody: [],
            from: webPage,
            frameInfo: nil)

        XCTAssertEqual(webPage.mouseHoveringLocation, .none)
    }

}

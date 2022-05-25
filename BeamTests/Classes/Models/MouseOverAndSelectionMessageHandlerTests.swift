import XCTest
@testable import Beam

class MouseOverAndSelectionMessageHandlerTests: XCTestCase {

    private var messageHandler: MouseOverAndSelectionMessageHandler!
    private var webPage: TestWebPage!
    private var browserTabConfiguration: BeamWebViewConfigurationBase!

    override func setUp() {
        webPage = TestWebPage(
            browsingScorer: nil,
            passwordOverlayController: nil,
            pns: nil,
            fileStorage: nil,
            downloadManager: nil,
            navigationHandler: nil
        )

        messageHandler = MouseOverAndSelectionMessageHandler()
        browserTabConfiguration = BeamWebViewConfigurationBase(handlers: [messageHandler])
    }

    func testMouseOverLink() {
        let body = [
            "url": "https://rickymartin.com/uno/dos/tres",
            "target": ""
        ]

        messageHandler.onMessage(
            messageName: MouseOverAndSelectionMessage.MouseOverAndSelection_linkMouseOver.rawValue,
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
            messageName: MouseOverAndSelectionMessage.MouseOverAndSelection_linkMouseOver.rawValue,
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
            messageName: MouseOverAndSelectionMessage.MouseOverAndSelection_linkMouseOver.rawValue,
            messageBody: [],
            from: webPage,
            frameInfo: nil)

        XCTAssertEqual(webPage.mouseHoveringLocation, .none)
    }

}

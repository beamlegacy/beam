//
//  IncognitoTests.swift
//  BeamTests
//
//  Created by Ludovic Ollagnier on 07/04/2022.
//

import XCTest
import Combine
@testable import Beam
@testable import BeamCore

class IncognitoTests: XCTestCase {

    func testIncognitoBeamStateConfig() throws {
        let state = BeamState(incognito: true)

        XCTAssertNotNil(state.incognitoCookiesManager)
        XCTAssertNil(state.webIndexingController)
        XCTAssertIdentical(state.cookieManager, state.incognitoCookiesManager)
    }

    func testIncognitoBrowsingTree() {
        let tree = BrowsingTree.incognitoBrowsingTree(origin: nil)

        XCTAssertNil(tree.domainPath0TreeStatsStore)
        XCTAssertNil(tree.longTermScoreStore)
        XCTAssertNil(tree.frecencyScorer)
        XCTAssertNil(tree.dailyScoreStore)
    }

    func testWebViewConfig() {
        let incognitoState = BeamState(incognito: true)

        let incognitoConfig = BrowserTab.incognitoWebViewConfiguration

        let incognitoTab = BrowserTab.init(state: incognitoState, browsingTreeOrigin: nil, originMode: .web, note: nil)
        let configIncognitoTab = incognitoTab.webView.configurationWithoutMakingCopy as! BeamWebViewConfigurationBase

        let loggingHandlers = configIncognitoTab.handlers.filter({ element in
            element is LoggingMessageHandler
        })

        let passwordHandlers = configIncognitoTab.handlers.filter({ element in
            element is PasswordMessageHandler
        })

        XCTAssertEqual(incognitoConfig.handlers.count, configIncognitoTab.handlers.count)
        // We should not have logging handlers to avoid JS logs
        XCTAssertTrue(loggingHandlers.isEmpty)
        // We should not have PasswordMessage to disable password manager usage
        XCTAssertTrue(passwordHandlers.isEmpty)

        let incognitoTab1 = BrowserTab.init(state: incognitoState, browsingTreeOrigin: nil, originMode: .web, note: nil)
        let configIncognitoTab1 = incognitoTab1.webView.configurationWithoutMakingCopy as! BeamWebViewConfigurationBase

        XCTAssertNotEqual(configIncognitoTab.websiteDataStore, configIncognitoTab1.websiteDataStore)

        let nonIncognitoTab = BrowserTab.init(state: BeamState(incognito: false), browsingTreeOrigin: nil, originMode: .web, note: nil)
        let nonIncognitoTab1 = BrowserTab.init(state: BeamState(incognito: false), browsingTreeOrigin: nil, originMode: .web, note: nil)

        let nonIncognitoTabConfig = nonIncognitoTab.webView.configurationWithoutMakingCopy as! BeamWebViewConfigurationBase
        let nonIncognitoTabConfig1 = nonIncognitoTab1.webView.configurationWithoutMakingCopy as! BeamWebViewConfigurationBase

        XCTAssertEqual(nonIncognitoTabConfig.websiteDataStore, nonIncognitoTabConfig1.websiteDataStore)
        XCTAssertNotEqual(configIncognitoTab1.websiteDataStore, nonIncognitoTabConfig1.websiteDataStore)
    }
}

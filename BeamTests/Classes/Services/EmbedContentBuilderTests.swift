//
//  EmbedContentBuilderTests.swift
//  BeamTests
//
//  Created by Remi Santos on 03/11/2021.
//

import XCTest
@testable import Beam

class EmbedContentBuilderTests: XCTestCase {

    class MockStrategy: EmbedContentStrategy {
        var canEmbed = true
        var returnContent: EmbedContent?
        private(set) var numberOfCallsToBuild = 0
        func canBuildEmbeddableContent(for url: URL) -> Bool { canEmbed }

        func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void) {
            numberOfCallsToBuild += 1
            completion(returnContent, nil)
        }
    }

    func testUseGivenStrategy() {
        let url = URL(string: "embed.com")!
        var builder = EmbedContentBuilder()
        builder.clearCache()
        let strategy = MockStrategy()
        builder.strategies = [strategy]
        strategy.canEmbed = true
        XCTAssertTrue(builder.canBuildEmbed(for: url))
        strategy.canEmbed = false
        XCTAssertFalse(builder.canBuildEmbed(for: url))

        let expectedContent = EmbedContent(title: "embed.com", type: .link, sourceURL: url, embedURL: url, html: "some content")
        strategy.returnContent = expectedContent

        let result = builder.embeddableContent(for: url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sourceURL, url)
        XCTAssertEqual(result?.html, "some content")
    }

    func testUseCache() {
        let url = URL(string: "embed.com")!
        var builder = EmbedContentBuilder()
        builder.clearCache()
        let strategy = MockStrategy()
        builder.strategies = [strategy]

        let expectedContent = EmbedContent(title: "embed.com", type: .link, sourceURL: url, embedURL: url, html: "some content")
        strategy.returnContent = expectedContent

        XCTAssertEqual(strategy.numberOfCallsToBuild, 0)
        let result = builder.embeddableContent(for: url)
        XCTAssertEqual(strategy.numberOfCallsToBuild, 1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sourceURL, url)
        XCTAssertEqual(result?.html, "some content")
        _ = builder.embeddableContent(for: url)
        _ = builder.embeddableContent(for: url)
        let last = builder.embeddableContent(for: url)
        XCTAssertEqual(strategy.numberOfCallsToBuild, 1)
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.sourceURL, url)
        XCTAssertEqual(last?.html, "some content")
    }
}

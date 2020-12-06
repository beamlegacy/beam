//
//  PageRankTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 03/12/2020.
//

import Foundation
import XCTest
@testable import Beam

class PageRangeTests: CoreDataTests {

    func testInit() throws {
        let pageRank = PageRank()

        pageRank.updatePage(source: "A", outbounds: ["B", "C"])
        pageRank.updatePage(source: "B", outbounds: ["C"])
        pageRank.updatePage(source: "C", outbounds: ["I"])
        pageRank.updatePage(source: "D", outbounds: ["A", "H"])
        pageRank.updatePage(source: "E", outbounds: ["A", "G"])
        pageRank.updatePage(source: "F", outbounds: ["A", "B"])
        pageRank.updatePage(source: "G", outbounds: ["A", "B", "C"])
        pageRank.updatePage(source: "H", outbounds: ["C"])
        pageRank.updatePage(source: "I", outbounds: ["B"])

        Logger.shared.logInfo("PageRank Before computation:\n", category: .document)
        pageRank.dump()

        pageRank.computePageRanks(iterations: 30)

        Logger.shared.logInfo("PageRank After computation:\n", category: .document)
        pageRank.dump()

        let total = pageRank.pages.reduce(0) { (val, page) -> Float in
            val + page.value.pageRank
        }

        Logger.shared.logInfo("PageRank total \(total) for \(pageRank.pages.count) pages", category: .general)
        XCTAssertEqual(total, 1.0, accuracy: 0.0015)
    }
}

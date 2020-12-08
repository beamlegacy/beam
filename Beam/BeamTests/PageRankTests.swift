//
//  PageRankTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 03/12/2020.
//

import Foundation
import XCTest
@testable import Beam
import NaturalLanguage
import Accelerate
import SwiftSoup

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

    func testEmbeddings() {
        let embeddingFrench = NLEmbedding.wordEmbedding(for: .french)
        let embeddingEnglish = NLEmbedding.wordEmbedding(for: .english)

        let frenchWord = "humain"
        let englishWord = "human"

        guard let frenchVector = embeddingFrench?.vector(for: frenchWord) else { fatalError() }
        guard let englishVector = embeddingEnglish?.vector(for: englishWord) else { fatalError() }

        Logger.shared.logInfo("French embedding '\(frenchWord) -> \(frenchVector)", category: .general)
        Logger.shared.logInfo("English embedding '\(englishWord) -> \(englishVector)", category: .general)

//        let stride = vDSP_Stride(1)

        XCTAssert(frenchVector.count == englishVector.count)
//        var result = frenchVector

//        vDSP_vdistD(frenchVector, stride,
//                   englishVector, stride,
//                   &result, stride,
//                   vDSP_Length(result.count))

        let result = vDSP.distanceSquared(frenchVector, englishVector)

        Logger.shared.logInfo(" -> distance '\(result)", category: .general)
    }

    var index = Index()

    func append(_ url: URL, contents: String) {
        print("Index url \(url)")
        do {
            //print("html -> \(html)")
            print("Index \(url)")
            let doc = try SwiftSoup.parse(contents, url.absoluteString)
            try index.append(document: IndexDocument(id: UUID(), source: url.absoluteString, title: doc.title(), contents: doc.text()))
        } catch Exception.Error(let type, let message) {
            print("Test (SwiftSoup parser) \(type): \(message)")
        } catch {
            print("Test: (SwiftSoup parser) unkonwn error")
        }

    }

    func testIndex() {
        let urls = [
            "https://en.wikipedia.org/wiki/Saeid_Taghizadeh",
            "https://en.wikipedia.org/wiki/Sarcohyla_cembra",
            "https://en.wikipedia.org/wiki/Induction-induction",
            "https://en.wikipedia.org/wiki/Robert_Logan_Jack",
            "https://en.wikipedia.org/wiki/Bulbophyllum_calceolus",
            "https://en.wikipedia.org/wiki/Steven_Welsh",
            "https://en.wikipedia.org/wiki/1948_Holy_Cross_Crusaders_football_team",
            "https://en.wikipedia.org/wiki/1958_ACC_Men%27s_Basketball_Tournament",
            "https://en.wikipedia.org/wiki/Festo_Corp._v._Shoketsu_Kinzoku_Kogyo_Kabushiki_Co.",
            "https://en.wikipedia.org/wiki/Lost_Lake_Woods,_Michigan",
            "https://en.wikipedia.org/wiki/Sport",
            "https://en.wikipedia.org/wiki/Competition",
            "https://en.wikipedia.org/wiki/Physical_activity",
            "https://en.wikipedia.org/wiki/Game",
            // "https://en.wikipedia.org/wiki/Entertainment"
        ]
        for url in urls {
            if let url = URL(string: url) {
                let expect = expectation(description: "load url \(url)")
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        //self.handleClientError(error)
                        Logger.shared.logError("Client error \(error)", category: .web)
                        expect.fulfill()
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode) else {
                        //self.handleServerError(response)
                        Logger.shared.logError("Server error \(response)", category: .web)
                        expect.fulfill()
                        return
                    }
                    if let mimeType = httpResponse.mimeType, mimeType == "text/html",
                        let data = data,
                        let string = String(data: data, encoding: .utf8) {
//                        DispatchQueue.main.async {
                            self.append(url, contents: string)
                            expect.fulfill()
//                        }
                    }
                }
                task.resume()

                waitForExpectations(timeout: 10) { error in
                    Logger.shared.logError("Load error \(error) \(url)", category: .web)
                }
            } else {
                Logger.shared.logError("unable to make \(url) into an URL object", category: .general)
            }
        }
        index.dump()
    }
}

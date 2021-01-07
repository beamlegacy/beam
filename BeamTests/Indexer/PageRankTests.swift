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

class PageRankTests: XCTestCase {

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

    struct SearchSource: Codable {
        var url: URL
        var data: String
    }
    var searchSources = [SearchSource]()

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
        "https://en.wikipedia.org/wiki/Entertainment"
    ]

    func fetchSources() {
        var expectations = [XCTestExpectation]()
        for url in urls {
            if let url = URL(string: url) {
                let expect = expectation(description: "load url \(url)")
                expectations.append(expect)
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
                        Logger.shared.logError("Server error \(String(describing: response))", category: .web)
                        expect.fulfill()
                        return
                    }
                    if let mimeType = httpResponse.mimeType, mimeType == "text/html",
                        let data = data,
                        let string = String(data: data, encoding: .utf8) {
//                        DispatchQueue.main.async {
                        self.searchSources.append(SearchSource(url: url, data: string))
                            expect.fulfill()
//                        }
                    }
                }
                task.resume()
            } else {
                Logger.shared.logError("unable to make \(url) into an URL object", category: .general)
            }
        }

        wait(for: expectations, timeout: 40, enforceOrder: false)

        guard let fileurl = tempFile(named: "PageRankFixtures.json") else {
            fatalError("Unable to save PageRankFixtures.json")
        }
        print("Save fixtures to file \(fileurl)")
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(searchSources)
            FileManager.default.createFile(atPath: fileurl.path, contents: data, attributes: [:])
        } catch {
            fatalError("Unable to save fixtures")
        }
    }

    func loadFixtures() {
        let fixtureData: Data = {
            do {
                let bundle = Bundle(for: type(of: self))
                let path = bundle.path(forResource: "PageRankFixtures", ofType: "json")!
                return try Data(contentsOf: URL(fileURLWithPath: path))
            } catch {
                fatalError("unable to load fixture data for search and indexing tests")
            }
        }()

        let decoder = JSONDecoder()
        do {
            searchSources = try decoder.decode([SearchSource].self, from: fixtureData)
        } catch {
            fatalError("Unable to decode search / page rank fixture data")
        }
    }

    func append(_ url: URL, contents: String) {
        do {
            //print("html -> \(html)")
            let parsingStart = CACurrentMediaTime()
            let doc = try SwiftSoup.parse(contents, url.absoluteString)
            let title = try doc.title()
            let text = html2Text(url: url, doc: doc)
            let indexingStart = CACurrentMediaTime()
            index.append(document: IndexDocument(source: url.absoluteString, title: title, contents: text, outboundLinks: doc.extractLinks()))
            let now = CACurrentMediaTime()
            print("Indexed \(url) (\(contents.count) characters - title: \(title.count) - text: \(text.count)) in \((now - parsingStart) * 1000) ms (parsing: \((indexingStart - parsingStart) * 1000) ms - indexing \((now - indexingStart) * 1000) ms")
        } catch Exception.Error(let type, let message) {
            print("Test (SwiftSoup parser) \(type): \(message)")
        } catch {
            print("Test: (SwiftSoup parser) unkonwn error")
        }

    }

    func tempFile(named filename: String) -> URL? {
        let template = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename) as NSURL

        // Fill buffer with a C string representing the local file system path.
        var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
        template.getFileSystemRepresentation(&buffer, maxLength: buffer.count)

        let url = URL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeTo: nil)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            } catch {
                fatalError()
            }
        }

        // Create unique file name (and open file):
        let fd = mkstemp(&buffer)
        if fd != -1 {

            // Create URL from file system string:
            return url

        } else {
            print("Error: " + String(cString: strerror(errno)))
        }

        return nil
    }

    func testIndex() {
        //fetchSources()
        loadFixtures()

        for source in searchSources {
            self.append(source.url, contents: source.data)
        }

        XCTAssertEqual(urls.count, index.documents.count)

        let start = CACurrentMediaTime()
        index.pageRank.computePageRanks(iterations: 20)
        let now = CACurrentMediaTime()
        let time = (now - start) * 1000
        print("PageRank update took \(time) ms")

        index.dump()

        XCTAssertGreaterThanOrEqual(search("sport").count, 4)
        XCTAssertGreaterThanOrEqual(search("rules").count, 4)
        XCTAssertGreaterThanOrEqual(search("perform").count, 5)
        XCTAssertGreaterThanOrEqual(search("wikipedia").count, 15)
        XCTAssertGreaterThanOrEqual(search("sport rules").count, 5)
        XCTAssertGreaterThanOrEqual(search("guitar").count, 0)

        XCTAssertEqual(LinkStore.shared.links.count, LinkStore.shared.ids.count)

        print("LinkStore contains \(LinkStore.shared.links.count) different links")

        do {
            let encoder = JSONEncoder()
            let data0 = try encoder.encode(index)
            encoder.outputFormatting = .prettyPrinted
            let data1 = try encoder.encode(index)
            print("Encoded index size = \(data0.count)")
            print("Encoded index size (pretty) = \(data1.count)")

            guard let fileurl0 = tempFile(named: "Index.json") else {
                fatalError("Unable to save Index.json")
            }
            print("Save index to file \(fileurl0)")
            FileManager.default.createFile(atPath: fileurl0.path, contents: data0, attributes: [:])

            guard let fileurl1 = tempFile(named: "IndexPretty.json") else {
                fatalError("Unable to save IndexPretty.json")
            }
            print("Save pretty index to file \(fileurl1)")
            FileManager.default.createFile(atPath: fileurl1.path, contents: data1, attributes: [:])
        } catch {
            fatalError()
        }
    }

    func search(_ string: String) -> [Index.SearchResult] {
        let start = CACurrentMediaTime()
        let results = index.search(string: string)
        let now = CACurrentMediaTime()

        printResults(string, now - start, results)
        return results
    }

    func printResults(_ searchString: String, _ time: CFTimeInterval, _ results: [Index.SearchResult]) {
        print("Search for '\(searchString)' (\(results.count) instance(s) in \(time * 1000) ms:")
        for res in results {
            print("\t\(res.score): \(res.source) / \(res.title)")
        }
    }
}

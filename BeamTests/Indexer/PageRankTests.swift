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
    private func testInit() throws {
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

    private func fetchSources() {
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
        Logger.shared.logDebug("Save fixtures to file \(fileurl)")
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(searchSources)
            FileManager.default.createFile(atPath: fileurl.path, contents: data, attributes: [:])
        } catch {
            fatalError("Unable to save fixtures")
        }
    }

    private func loadFixtures() {
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

    private func append(_ url: URL, contents: String) throws {
//        do {
            //Logger.shared.logDebug("html -> \(html)")
//            let parsingStart = CACurrentMediaTime()
            let doc = try SwiftSoup.parse(contents, url.absoluteString)
            let title = try doc.title()
        let text: String = html2Text(url: url, doc: doc)
//            let indexingStart = CACurrentMediaTime()
            index.append(document: IndexDocument(source: url.absoluteString, title: title, contents: text, outboundLinks: doc.extractLinks()))
//            let now = CACurrentMediaTime()
//            Logger.shared.logDebug("Indexed \(url) (\(contents.count) characters - title: \(title.count) - text: \(text.count)) in \((now - parsingStart) * 1000) ms (parsing: \((indexingStart - parsingStart) * 1000) ms - indexing \((now - indexingStart) * 1000) ms")
//        } catch Exception.Error(let type, let message) {
////            Logger.shared.logDebug("Test (SwiftSoup parser) \(type): \(message)")
//        } catch {
////            Logger.shared.logDebug("Test: (SwiftSoup parser) unknown error")
//        }
    }

    private func tempFile(named filename: String) -> URL? {
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
            Logger.shared.logDebug("Error: " + String(cString: strerror(errno)))
        }

        return nil
    }

    func testIndex() {
        //fetchSources()
        loadFixtures()

        for source in searchSources {
            try? self.append(source.url, contents: source.data)
        }

        XCTAssertEqual(urls.count, index.documents.count)

        let start = CACurrentMediaTime()
        index.pageRank.computePageRanks(iterations: 20)
        let now = CACurrentMediaTime()
        let time = (now - start) * 1000
        Logger.shared.logDebug("PageRank update took \(time) ms")

        index.dump()

        XCTAssertGreaterThanOrEqual(search("sport").count, 4)
        XCTAssertGreaterThanOrEqual(search("rules").count, 4)
        XCTAssertGreaterThanOrEqual(search("perform").count, 5)
        XCTAssertGreaterThanOrEqual(search("wikipedia").count, 15)
        XCTAssertGreaterThanOrEqual(search("sport rules").count, 5)
        XCTAssertGreaterThanOrEqual(search("guitar").count, 0)

//        Logger.shared.logDebug("LinkStore contains \(LinkStore.shared.links.count) different links")

        do {
            let encoder = JSONEncoder()
            let data0 = try encoder.encode(index)
            encoder.outputFormatting = .prettyPrinted
            let data1 = try encoder.encode(index)
//            Logger.shared.logDebug("Encoded index size = \(data0.count)")
//            Logger.shared.logDebug("Encoded index size (pretty) = \(data1.count)")

            guard let fileurl0 = tempFile(named: "Index.json") else {
                fatalError("Unable to save Index.json")
            }
//            Logger.shared.logDebug("Save index to file \(fileurl0)")
            FileManager.default.createFile(atPath: fileurl0.path, contents: data0, attributes: [:])

            guard let fileurl1 = tempFile(named: "IndexPretty.json") else {
                fatalError("Unable to save IndexPretty.json")
            }
//            Logger.shared.logDebug("Save pretty index to file \(fileurl1)")
            FileManager.default.createFile(atPath: fileurl1.path, contents: data1, attributes: [:])
        } catch {
            fatalError()
        }
    }

    private func search(_ string: String) -> [Index.SearchResult] {
//        let start = CACurrentMediaTime()
        let results = index.search(string: string)
//        let now = CACurrentMediaTime()

//        printResults(string, now - start, results)
        return results
    }

    private func printResults(_ searchString: String, _ time: CFTimeInterval, _ results: [Index.SearchResult]) {
        Logger.shared.logDebug("Search for '\(searchString)' (\(results.count) instance(s) in \(time * 1000) ms:")
        for res in results {
            Logger.shared.logDebug("\t\(res.score): \(res.source) / \(res.title)")
        }
    }

    func compareNamedEntities(list1: [(String, NLTag)], list2: [(String, NLTag)], _ message: String, file: StaticString, line: UInt) {
        XCTAssertEqual(list1.count, list2.count)
        for i in 0..<list1.count {
            XCTAssertEqual(list1[i].0, list2[i].0, message, file: file, line: line)
            XCTAssertEqual(list1[i].1, list2[i].1, message, file: file, line: line)
        }
    }

    func checkNamedEntities(_ language: NLLanguage?, _ str: String, _ list: [(String, NLTag)], _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        compareNamedEntities(list1: list, list2: str.getNamedEntities(language), message, file: file, line: line)
    }

    func testNamedEntitiesExtraction() {
//        checkNamedEntities(.french, "Je m'appelle Sébastien et je travaille chez Beam à Paris",
//                             [("Sébastien", NLTag.personalName), ("Paris", NLTag.placeName)], "test1")

        checkNamedEntities(.english, "My name is Seb and I work for Beam in Paris",
                        [("Paris", NLTag.placeName)], "test2")

        checkNamedEntities(.english, "I used to work for Apple in Paris",
                        [("Paris", NLTag.placeName)], "test3")

        checkNamedEntities(.english, "I started building guitars because the left handed offerings from Fender and Gibson was really subpar...",
                        [("Fender", NLTag.organizationName), ("Gibson", NLTag.personalName)], "test4")
    }

    func testTF() {
        let index = Index()
        let doc1 = IndexDocument(source: "doc1", title: "First document", contents: "This is the first document in the collection. It talks about nothing in particular.")
        let doc2 = IndexDocument(source: "doc2", title: "Second document", contents: "I would like to eat something good. Maybe go to a nice restaurant tonight.")
        let doc3 = IndexDocument(source: "doc3", title: "third document", contents: "He is a food critict so he visits many restaurants to eat a lot. But nobody really cares what he likes so he's like the worst critic there is.")

        let docs = [doc1, doc2, doc3]

        for d in docs {
            index.append(document: d)
        }

        XCTAssertEqual(index.documents.count, 3)

        let query = "Eat nice food or nothing guys"
        let frequencies = index.wordFrequency(for: query)
        let tfidf = index.tfidf(for: query)

        let expectedFrequencies: [String: Int] = ["eat": 1, "food": 1, "or": 1, "nothing": 1, "guys": 1, "nice": 1]
        XCTAssertEqual(frequencies.count, expectedFrequencies.count)
        for w in expectedFrequencies {
            XCTAssertEqual(w.value, frequencies[w.key])
        }

        let expectedTfidf: [String: Float] = ["guys": 0.0, "eat": 0.4054651, "or": 0.0, "food": 1.0986123, "nothing": 1.0986123, "nice": 1.0986123]
        XCTAssertEqual(tfidf.count, expectedTfidf.count)
        for w in expectedTfidf {
            XCTAssertEqual(w.value, tfidf[w.key] ?? 0, accuracy: 0.00001)
        }
    }
}

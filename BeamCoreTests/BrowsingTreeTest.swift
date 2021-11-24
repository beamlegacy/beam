//
//  BrowsingTreeTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 19/08/2021.
//

import XCTest
@testable import BeamCore

class BrowsingTreeTest: XCTestCase {

    func testDeserialization() {

        let jsonTree = """
        {"origin": {"type": "searchBar", "value": "patrick dewaere"},
         "root": {"children": [{"events": [{"date": 643295386.78019,
                                            "type": "creation"},
                                           {"date": 643295386.780228,
                                            "type": "startReading"},
                                           {"date": 643295391.950899,
                                            "type": "navigateToLink"},
                                           {"date": 643295421.472989,
                                            "type": "startReading"},
                                           {"date": 643295439.820442,
                                            "type": "navigateToLink"},
                                           {"date": 643295446.507388,
                                            "type": "startReading"}],
                                "id": "4045225C-5E34-4520-9C46-BC7450837F6F",
                                "link": "CB95AAF0-B3DF-4CBA-B92E-9051AA959FAE"}],
                  "events": [{"date": 643295384.698409, "type": "creation"},
                             {"date": 643295385.234729, "type": "startReading"},
                             {"date": 643295386.780153, "type": "searchBarNavigation"}],
                  "id": "313D8A29-1C6D-4A0A-9970-12293C1CCA2B",
                  "link": "46C67F6A-8B3A-42E1-86DE-E3AE5C66AAFE"},
         "scores": ["46C67F6A-8B3A-42E1-86DE-E3AE5C66AAFE",
                    {"area": 3747357,
                     "inbounds": 0,
                     "openIndex": 0,
                     "outbounds": 0,
                     "readingTime": 0,
                     "scrollRatioX": 0,
                     "scrollRatioY": 0.34304097294807434,
                     "textAmount": 1594,
                     "textSelections": 0,
                     "videoReadingDuration": 0,
                     "videoTotalDuration": 0}]}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(BrowsingTree.self, from: jsonTree)
        } catch { XCTFail("Error: \(error)") }
    }

    func testWebSessionId() throws {
        BeamDate.freeze()
        let sessionDuration = WebSessionnizer.sessionDuration
        let tree = BrowsingTree(nil)
        let sessionId0 = try XCTUnwrap(tree.current.events.first?.webSessionId)

        //reading events separated by less than session duration bear the same sessionId
        BeamDate.travel(sessionDuration - 1)
        tree.navigateTo(url: "www.google.com", title: nil, startReading: true, isLinkActivation: false, readCount: 0)
        let sessionId1 = try XCTUnwrap(tree.current.events.last?.webSessionId)
        XCTAssertEqual(sessionId0, sessionId1)

        //reading events separated by more than session duration bear different sessionIds
        BeamDate.travel(sessionDuration + 1)
        tree.switchToBackground()
        let sessionId2 = try XCTUnwrap(tree.current.events.last?.webSessionId)
        XCTAssertNotEqual(sessionId1, sessionId2)

        //sessionId is maintained accross browsing trees
        let anotherTree = BrowsingTree(nil)
        let sessionId3 = try XCTUnwrap(anotherTree.current.events.first?.webSessionId)
        XCTAssertEqual(sessionId2, sessionId3)

        BeamDate.reset()

    }

    func testPageLoadId() throws {

        func assertCountDistinctPageLoadIds(node: BrowsingNode, leftBound: Int? = nil, rightBound: Int? = nil, expectedCount: Int) {
            let leftBoundUnwrapped = leftBound ?? 0
            let rightBoundUnwrapped = rightBound ?? node.events.count
            let pageLoadIdsSlice = node.events[leftBoundUnwrapped..<rightBoundUnwrapped].map {$0.pageLoadId}
            XCTAssertEqual(Set(pageLoadIdsSlice).count, expectedCount)
        }

        let tree = BrowsingTree(nil)

        tree.navigateTo(url: "www.moon.com", title: nil, startReading: true, isLinkActivation: false, readCount: 0)
        let node0 = try XCTUnwrap(tree.current)
        tree.switchToBackground()
        tree.startReading()

        //node 0 will switch to a new page load id
        tree.navigateTo(url: "www.sun.com", title: nil, startReading: true, isLinkActivation: false, readCount: 0)
        let node0NavigatedIndex = node0.events.count

        let node1 = try XCTUnwrap(tree.current)
        tree.switchToBackground()
        tree.startReading()

        //node 1 will switch to a new page load id
        tree.goBack()
        let node1MovedBackIndex = node1.events.count

        tree.switchToBackground()
        tree.startReading()
        tree.goForward()

        tree.startReading()
        tree.goForward()

        assertCountDistinctPageLoadIds(node: node0, expectedCount: 2)
        assertCountDistinctPageLoadIds(node: node0, rightBound: node0NavigatedIndex, expectedCount: 1)
        assertCountDistinctPageLoadIds(node: node0, leftBound: node0NavigatedIndex, expectedCount: 1)
        assertCountDistinctPageLoadIds(node: node1, expectedCount: 2)
        assertCountDistinctPageLoadIds(node: node1, rightBound: node1MovedBackIndex, expectedCount: 1)
        assertCountDistinctPageLoadIds(node: node1, leftBound: node1MovedBackIndex, expectedCount: 1)
    }

    func testBrowsingNodeOriginSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        //decode(encode(x)) is identity
        let origin: BrowsingTreeOrigin = .browsingNode(id: UUID(), pageLoadId: UUID(), rootOrigin: .searchBar(query: "rolex pas cher"))
        let encoded = try encoder.encode(origin)
        let decoded = try decoder.decode(BrowsingTreeOrigin.self, from: encoded)
        XCTAssertEqual(origin, decoded)

        //previous version of origin without pageLoadId and rootOrigin can decode as well
        let jsonWithIdOnly = """
                            {"type": "browsingNode", "value": "5b173771-7f30-4ac8-80ce-b12b38c347ba"}
                            """.data(using: .utf8)!
        do {
            _ = try decoder.decode(BrowsingTreeOrigin.self, from: jsonWithIdOnly)
        } catch { XCTFail("Error: \(error)") }
    }

    func testIdUrlMapping() throws {
        let tree = BrowsingTree(nil)
        let root = tree.current!
        tree.navigateTo(url: "www.chocolate.com", title: nil, startReading: true, isLinkActivation: false, readCount: 0)
        let current = tree.current!
        var mapping = [UUID: String]()
        mapping[root.link] = "<???>"
        mapping[current.link] = "www.chocolate.com"
        XCTAssertEqual(tree.idUrlMapping, mapping)
    }

    //swiftlint:disable:next function_body_length
    func testUrlIdMigration() throws {
        //Checks that a tree bearing legacy Uint64 urlId can be decoded and detected as legacy
        var legacyJson = """
        {"origin": {"type": "searchBar", "value": "patrick dewaere"},
         "root": {"children": [{"events": [{"date": 643295386.78019, "type": "creation"}],
                                "id": "4045225C-5E34-4520-9C46-BC7450837F6F",
                                "link": 0}],
                  "events": [{"date": 643295384.698409, "type": "creation"}],
                  "id": "313D8A29-1C6D-4A0A-9970-12293C1CCA2B",
                  "link": 1 },
         "scores": [0,
                    {"area": 3747357,
                     "inbounds": 0,
                     "openIndex": 0,
                     "outbounds": 0,
                     "readingTime": 0,
                     "scrollRatioX": 0,
                     "scrollRatioY": 0.34304097294807434,
                     "textAmount": 1594,
                     "textSelections": 0,
                     "videoReadingDuration": 0,
                     "videoTotalDuration": 0}
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var legacyDecoded = try XCTUnwrap(try? decoder.decode(BrowsingTree.self, from: legacyJson))
        var legacyRoot = try XCTUnwrap(legacyDecoded.root)
        XCTAssert(legacyRoot.legacy)
        //Checks that additionnal encode decode doesnt loose the legacy information
        legacyJson = try XCTUnwrap(try? encoder.encode(legacyDecoded))
        legacyDecoded = try XCTUnwrap(try? decoder.decode(BrowsingTree.self, from: legacyJson))
        legacyRoot = try XCTUnwrap(legacyDecoded.root)
        XCTAssert(legacyRoot.legacy)

        //Checks that encode decode works properly for non legacy trees
        let currentTree = BrowsingTree(nil)
        let rootUrlId = currentTree.root.link
        currentTree.navigateTo(url: "http://cool.cat", title: nil, startReading: true, isLinkActivation: false, readCount: 10)
        let childUrlId = currentTree.current.link
        XCTAssert(!currentTree.root.legacy)
        let currentJson = try XCTUnwrap(try? encoder.encode(currentTree))
        let decodedCurrentTree = try XCTUnwrap(try? decoder.decode(BrowsingTree.self, from: currentJson))
        XCTAssert(!decodedCurrentTree.root.legacy)
        XCTAssertEqual(currentTree.scores, decodedCurrentTree.scores)
        XCTAssertEqual(rootUrlId, decodedCurrentTree.root.link)
        XCTAssertEqual(childUrlId, decodedCurrentTree.current.link)
    }
}

//
//  BrowsingTreeTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 19/08/2021.
//

import XCTest
@testable import BeamCore

class BrowsingTreeTest: XCTestCase {
    override func setUpWithError() throws {
        super.setUp()
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
    }
    override func tearDownWithError() throws {
        super.tearDown()
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
    }

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

        let decoder = BeamJSONDecoder()
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
        let decoder = BeamJSONDecoder()

        //decode(encode(x)) is identity
        let origin: BrowsingTreeOrigin = .browsingNode(id: UUID(), pageLoadId: UUID(), rootOrigin: .searchBar(query: "rolex pas cher", referringRootId: nil), rootId: UUID())
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

        let decoder = BeamJSONDecoder()
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

    func testForegroundSegment() {
        BeamDate.freeze("2001-01-01T00:00:00+0000")
        let tree = BrowsingTree(nil)

        //first foreground segment start
        tree.startReading()
        BeamDate.travel(2.0)
        //first foreground segment end
        tree.switchToBackground()
        BeamDate.travel(1.0)
        //previous segment is already closed
        tree.switchToBackground()
        BeamDate.travel(1.0)
        //second segment start
        tree.startReading()
        BeamDate.travel(1.0)
        //second segment already started
        tree.startReading()
        //second segment end
        BeamDate.travel(2.0)
        tree.switchToBackground()

        let foregoundSegments = tree.current.foregroundSegments
        XCTAssertEqual(foregoundSegments.count, 2)
        XCTAssertEqual(foregoundSegments[0].start, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(foregoundSegments[0].end, Date(timeIntervalSinceReferenceDate: 2))
        XCTAssertEqual(foregoundSegments[0].duration, 2)
        XCTAssertEqual(foregoundSegments[1].start, Date(timeIntervalSinceReferenceDate: 4))
        XCTAssertEqual(foregoundSegments[1].end, Date(timeIntervalSinceReferenceDate: 7))
        XCTAssertEqual(foregoundSegments[1].duration, 3)

        BeamDate.reset()
    }

    //swiftlint:disable:next function_body_length
    func testFlattenUnflatten() throws {

        func isEqual(_ leftNode: BrowsingNode, _ rightNode: BrowsingNode) {
            XCTAssertEqual(leftNode.id, rightNode.id)
            XCTAssertEqual(leftNode.link, rightNode.link)
            XCTAssertEqual(leftNode.events, rightNode.events)
            XCTAssertEqual(leftNode.legacy, rightNode.legacy)
            XCTAssertEqual(leftNode.isLinkActivation, rightNode.isLinkActivation)

        }
        func isSerializable(node: BrowsingNode) {
            XCTAssertNil(node.parent)
            XCTAssertEqual(node.children.count, 0)
        }

        let urls = [
            "http://awesome.com",
            "http://fantastic.co.uk",
            "http://amazing.org",
            "http://greeeat.fr"
        ]
        let tree = BrowsingTree(nil)
        tree.navigateTo(url: urls[0], title: nil, startReading: true, isLinkActivation: false, readCount: 0)
        let node0 = try XCTUnwrap(tree.current)
        tree.navigateTo(url: urls[1], title: nil, startReading: true, isLinkActivation: true, readCount: 5)
        tree.navigateTo(url: urls[2], title: nil, startReading: true, isLinkActivation: true, readCount: 10)
        let node2 = try XCTUnwrap(tree.current)
        tree.goBack()
        let node1 = try XCTUnwrap(tree.current)
        tree.goBack()
        tree.navigateTo(url: urls[3], title: nil, startReading: true, isLinkActivation: true, readCount: 20)
        let node3 = try XCTUnwrap(tree.current)
        //Tree stucture is
        //root--node0--node1--node2
        //            \_node3

        let flattened = tree.flattened
        XCTAssertEqual(flattened.nodes.count, 5)
        let encoder = JSONEncoder()
        let decoder = BeamJSONDecoder()
        let data = try encoder.encode(flattened)
        let decoded = try decoder.decode(FlatennedBrowsingTree.self, from: data)

        //check that reconstructed tree structure is similar to initial tree
        let unflattened = try XCTUnwrap(BrowsingTree(flattenedTree: decoded))
        let unflattenedRoot = try XCTUnwrap(unflattened.root)
        isEqual(tree.root, unflattened.root)
        XCTAssertEqual(unflattenedRoot.children.count, 1)
        let unflattenedNode0 = unflattenedRoot.children[0]
        isEqual(unflattenedNode0, node0)
        XCTAssertEqual(unflattenedNode0.children.count, 2)
        let unflattenedNode1 = unflattenedNode0.children[0]
        isEqual(unflattenedNode1, node1)
        XCTAssertEqual(unflattenedNode1.children.count, 1)
        let unflattenedNode2 = unflattenedNode1.children[0]
        isEqual(unflattenedNode2, node2)
        XCTAssertEqual(unflattenedNode2.children.count, 0)
        let unflattenedNode3 = unflattenedNode0.children[1]
        isEqual(unflattenedNode3, node3)
        XCTAssertEqual(unflattenedNode3.children.count, 0)
        XCTAssertIdentical(unflattenedNode3, unflattened.current)
        XCTAssertEqual(tree.scores, unflattened.scores)

        //checks that decoded wasn't mutated when given as input of BrowsingTree(flattenedTree:)
        for node in decoded.nodes {
            isSerializable(node: node)
        }
    }

    func testTreeOriginAnonymization() {
        //search bar case
        let referringId = UUID()
        let searchBarOrigin: BrowsingTreeOrigin = .searchBar(query: "query", referringRootId: referringId)
        if case .searchBar(query: let query, referringRootId: let anonymizedId) = searchBarOrigin.anonymized {
            XCTAssertNil(query)
            XCTAssertEqual(referringId, anonymizedId)
        } else {
            XCTFail("Tree origin anonymization issue")
        }

        //search from node case
        let searchFromNoteOrigin: BrowsingTreeOrigin = .searchFromNode(nodeText: "node")
        if case .searchFromNode(nodeText: let text) = searchFromNoteOrigin.anonymized {
            XCTAssertNil(text)
        } else {
            XCTFail("Tree origin anonymization issue")
        }

        //link from note case
        let linkFromNoteOrigin: BrowsingTreeOrigin = .linkFromNote(noteName: "note")
        if case .linkFromNote(noteName: let noteName) = linkFromNoteOrigin.anonymized {
            XCTAssertNil(noteName)
        } else {
            XCTFail("Tree origin anonymization issue")
        }

        //cmd + click case
        let nodeOrigin: BrowsingTreeOrigin = .browsingNode(id: UUID(), pageLoadId: UUID(), rootOrigin: searchBarOrigin, rootId: UUID())
        if case let .browsingNode(id: _, pageLoadId: _, rootOrigin: .searchBar(query: query, referringRootId: _), rootId: _) = nodeOrigin.anonymized {
            XCTAssertNil(query)
        } else {
            XCTFail("Tree origin anonymization issue")
        }
    }

    func testTreeAnonymization() {
        let referringId = UUID()
        let tree = BrowsingTree(.searchBar(query: "query", referringRootId: referringId))
        let anonymizedTree = tree.anonymized
        XCTAssert(tree.root === anonymizedTree.root)
        XCTAssert(tree.current === anonymizedTree.current)
        XCTAssertEqual(tree.scores, anonymizedTree.scores)
        if case .searchBar(query: let query, referringRootId: let anonymizedId) = anonymizedTree.origin {
            XCTAssertNil(query)
            XCTAssertEqual(referringId, anonymizedId)
        } else {
            XCTFail("Tree origin anonymization issue")
        }
    }
}

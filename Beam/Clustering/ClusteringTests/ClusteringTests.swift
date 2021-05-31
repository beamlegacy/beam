//
//  ClusteringTests.swift
//  ClusteringTests
//
//  Created by Gil Katz on 17/05/2021.
//

import Nimble
import XCTest
import LASwift
@testable import Clustering

class ClusteringTests: XCTestCase {
    
    func testNavigationMatrix() throws {
        // This is a test of the navigation matrix struct
        let cluster = Cluster()
        XCTAssert(cluster.navigationMatrix.matrix == Matrix([[0]]))
        expect { try cluster.navigationMatrix.addPage(similarities: [1.0]) }.toNot(throwError())
        XCTAssert(cluster.navigationMatrix.matrix == Matrix([[0, 1.0], [1.0, 0]]))
        expect { try cluster.navigationMatrix.addPage(similarities: [0, 1]) }.toNot(throwError())
        XCTAssert(cluster.navigationMatrix.matrix == Matrix([[0, 1, 0], [1, 0, 1], [0, 1, 0]]))
        expect { try cluster.navigationMatrix.addPage(similarities: [1, 0]) }.to(throwError()) // Dimension mismatch
        expect { try cluster.navigationMatrix.removePage(pageNumber: 1) }.toNot(throwError())
        XCTAssert(cluster.navigationMatrix.matrix == Matrix([[0, 1], [1, 0]]))
    }
    
    func testClusterize() throws {
        // This is a test of the clusterize method. The corrent clustering is [0, 0, 1, 1, 2, 3, 3, 4, 0, 0])
        var i = 0
        let cluster = Cluster()
        var clustersResult = [Int]()
        cluster.adjacencyMatrix.matrix = Matrix([[0, 1, 0, 0, 0, 0, 0, 0, 1, 1,],
                                                 [1, 0, 0, 0, 0, 0, 0, 0, 0, 0,],
                                                 [0, 0, 0, 1, 0, 0, 0, 0, 0, 0,],
                                                 [0, 0, 1, 0, 0, 0, 0, 0, 0, 0,],
                                                 [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,],
                                                 [0, 0, 0, 0, 0, 0, 1, 0, 0, 0,],
                                                 [0, 0, 0, 0, 0, 1, 0, 0, 0, 0,],
                                                 [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,],
                                                 [1, 0, 0, 0, 0, 0, 0, 0, 0, 0,],
                                                 [1, 0, 0, 0, 0, 0, 0, 0, 0, 0,]])
        repeat {
            let predictedClusters = cluster.clusterize()
            clustersResult = cluster.stabilize(predictedClusters)
            i += 1
        } while clustersResult != [0, 0, 1, 1, 2, 3, 3, 4, 0, 0] && i < 3
        XCTAssert(clustersResult == [0, 0, 1, 1, 2, 3, 3, 4, 0, 0]) //This should pass ALMOST every time. There is some randomness in the algorithm...
    }
    
    func testProcessWithOnlyNavigation() throws {
        //Test the whole process of starting a session, adding pages and clustering, when only a  navigation matrix is available. For now no removal of pages
        let cluster = Cluster()
        let ids: [Int64] = Array(0...5)
        // The ids array is not necessary at the moment as its values are equivalent to their indexes
        // but hopefully in the future we'll have a better way to identify web pages in Beam
        let parents = [1: 0, 2: 0, 4: 3, 5: 1] // Page 0 and 3 are "new"
        let correct_results = [[[ids[0]]], [[ids[0], ids[1]]], [[ids[0], ids[1], ids[2]]], [[ids[0], ids[1], ids[2]], [ids[3]]], [[ids[0], ids[1], ids[2]], [ids[3], ids[4]]], [[ids[0], ids[1], ids[2], ids[5]], [ids[3], ids[4]]]]
        let expectation = XCTestExpectation(description: "Add page expectation")
        for i in 0...5 {
            var from: Int64?
            if let parent = parents[i] {
                from = ids[parent]
            }
            let page = Page(id: ids[i], parentId: from, title: nil, content: nil)
            try cluster.add(page, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    XCTAssert(result == correct_results[i])
                }
                if i == 5 {
                    expectation.fulfill()
                }
            })
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testRunTimeLargeMatrix() throws {
        let cluster = Cluster()
        let ids: [Int64] = Array(0...100)
        // The ids array is not necessary at the moment as its values are equivalent to their indexes
        // but hopefully in the future we'll have a better way to identify web pages in Beam
        let page = Page(id: ids[0], parentId: nil, title: nil, content: nil)
        try cluster.add(page, completion: { result in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            default: break
            }
        })
        
        for i in 1...99 {
            var from: Int64?
            
            if Double.random(in: 0...1) > 0.2 {
                from = ids[Int.random(in: 0..<i)]
            }
            let page = Page(id: ids[i], parentId: from, title: nil, content: nil)
            try cluster.add(page, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                default: break
                }
            })
        }
        sleep(5)
        // We want to measure the addition of the 100th page,
        // not the previous additions that might still be in the queue
        measure {
            var final_result = [[Int64]]()
            var from: Int64?
            
            if Double.random(in: 0...1) > 0.2 {
                from = ids[Int.random(in: 0..<100)]
            }
            let page = Page(id: ids[100], parentId: from, title: nil, content: nil)
            expect { try cluster.add(page, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    final_result = result
                }
            }) }.toNot(throwError())
            expect { final_result.count > 0 }.toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(10))
        }
        
    }
}

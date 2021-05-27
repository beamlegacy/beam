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
            cluster.clusterize()
            cluster.stabeliseClusters()
            i += 1
        } while cluster.clusters != [0, 0, 1, 1, 2, 3, 3, 4, 0, 0] && i < 3
        XCTAssert(cluster.clusters == [0, 0, 1, 1, 2, 3, 3, 4, 0, 0]) //This should pass ALMOST every time. There is some randomness in the algorithm...
    }
    
    func testProcessWithOnlyNavigation() throws {
        //Test the whole process of starting a session, adding pages and clustering, when only a  navigation matrix is available. For now no removal of pages
        let cluster = Cluster()
        let uuids = (0...5).map { _ in UUID() }
        let parents = [1: 0, 2: 0, 4: 3, 5: 1] // Page 0 and 3 are "new"
        for i in 0...5 {
            var from: UUID?
            if let parent = parents[i] {
                from = uuids[parent]
            }
            expect { try cluster.addPage(id: uuids[i], from: from) }.toNot(throwError())
        }
        XCTAssert(cluster.clusters == [0, 0, 0, 1, 1, 0])
    }
    
    func testLargeMatrix() throws {
        let cluster = Cluster()
        expect { try cluster.addPage(id: UUID(), from: nil) }.toNot(throwError())
        for _ in 1..<100 {
            let start = CFAbsoluteTimeGetCurrent()
            var from: UUID?
            
            if Double.random(in: 0...1) > 0.2 {
                from = cluster.pageIDs[Int.random(in: 0..<cluster.pageIDs.count)]
            }
            
            expect { try cluster.addPage(id: UUID(), from: from) }.toNot(throwError())

             let diff = CFAbsoluteTimeGetCurrent() - start
             XCTAssert(diff < 0.5)
        }
        
        measure {
            var from: UUID?
            
            if Double.random(in: 0...1) > 0.2 {
                from = cluster.pageIDs[Int.random(in: 0..<cluster.pageIDs.count)]
            }
            
            expect { try cluster.addPage(id: UUID(), from: from) }.toNot(throwError())
        }
    }
}

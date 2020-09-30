//
//  BeamTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import XCTest
@testable import Beam

class BeamTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSearch() throws {
        let sk = SearchKit()
        sk.append(url: URL(string: "http://test.com/test1")!, contents: String.loremIpsum)
        sk.append(url: URL(string: "http://test.com/test2")!, contents: "Beam is so cool!")
        
        let res = sk.search("cool")
        XCTAssert(!res.isEmpty)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}

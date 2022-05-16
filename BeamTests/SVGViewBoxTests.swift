//
//  SVGViewBoxTests.swift
//  BeamTests
//
//  Created by Stef Kors on 12/05/2022.
//

import XCTest

@testable import Beam

class SVGViewBoxTests: XCTestCase {

    func testInitFromString4Values() throws {
        let string = "0 0 24 34"
        let viewbox = SVGViewBox(string)
        XCTAssertEqual(viewbox?.minX, 0)
        XCTAssertEqual(viewbox?.minY, 0)
        XCTAssertEqual(viewbox?.width, 24)
        XCTAssertEqual(viewbox?.height, 34)
    }

    func testInitFromString3Values() throws {
        let string = "0 24 34"
        let viewbox = SVGViewBox(string)
        XCTAssertEqual(viewbox?.minX, nil)
        XCTAssertEqual(viewbox?.minY, 0)
        XCTAssertEqual(viewbox?.width, 24)
        XCTAssertEqual(viewbox?.height, 34)
    }

    func testInitFromString2Values() throws {
        let string = "24 34"
        let viewbox = SVGViewBox(string)
        XCTAssertEqual(viewbox?.minX, nil)
        XCTAssertEqual(viewbox?.minY, nil)
        XCTAssertEqual(viewbox?.width, 24)
        XCTAssertEqual(viewbox?.height, 34)
    }

    func testInitFromString1Value() throws {
        let string = "34"
        let viewbox = SVGViewBox(string)
        XCTAssertEqual(viewbox?.minX, nil)
        XCTAssertEqual(viewbox?.minY, nil)
        XCTAssertEqual(viewbox?.width, nil)
        XCTAssertEqual(viewbox?.height, 34)
    }

    func testInitFromWidthHeightStrings() throws {
        let viewbox = SVGViewBox(width: "200", height: "300")
        XCTAssertEqual(viewbox?.minX, nil)
        XCTAssertEqual(viewbox?.minY, nil)
        XCTAssertEqual(viewbox?.width, 200)
        XCTAssertEqual(viewbox?.height, 300)
    }

    func testInitFromWidthHeightPxStrings() throws {
        let viewbox = SVGViewBox(width: "200px", height: "300px")
        XCTAssertEqual(viewbox?.minX, nil)
        XCTAssertEqual(viewbox?.minY, nil)
        XCTAssertEqual(viewbox?.width, 200)
        XCTAssertEqual(viewbox?.height, 300)
    }

}

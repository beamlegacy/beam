//
//  Html2MdTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import XCTest
import Foundation
@testable import Beam

class Html2MdTests: XCTestCase {
    override func setUp() {
        super.setUp()

    }

    func test1() {
        let html = """
        <span>en orientation dans le cadre d'un processus d'orientation, par ...</span>
        <span>
            <span> </span>
            <a  href="https://fr.wikipedia.org/wiki/Test_(psychologie)">
                Wikipédia
            </a>
        </span>
        """

        let md = html2Md(url: URL(string: "http://test.com")!, html: html)
        //Logger.shared.logDebug("MD: \(md)")

        XCTAssertEqual(md, "en orientation dans le cadre d'un processus d'orientation, par ...    [Wikipédia](https://fr.wikipedia.org/wiki/Test_%28psychologie%29)")
    }

}

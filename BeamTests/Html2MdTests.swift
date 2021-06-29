//
//  Html2MdTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import  Nimble
import XCTest
import Foundation
import SwiftSoup
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
    
    func testHtml2TextForClustering() {
        let html = """
        <!DOCTYPE html>
        <html>
            <body>
                <p>This is a paragraph.</p>
                <p>This is another paragraph.</p>
            </body>
        </html>
        """
        guard let doc = try? SwiftSoup.parse(html) else { return }
        let txt = html2TextForClustering(doc: doc)

        expect(txt) == "This is another paragraph."

        // XCTAssertEqual(txt, "This is a paragraph.This is another paragraph.")
    }
}

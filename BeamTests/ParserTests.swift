//
//  ParserTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 13/10/2020.
//

import Foundation
import XCTest
import Nimble

@testable import Beam

class ParserTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testParser1() {
        let string = "Test of _a_ **simple** [[parser]] with a normal [link](url) test"
        let parser = Parser(inputString: string)
        let AST = parser.parseAST()
        let expectedResult = """
        Node[text("")]
            Node[text("Test of ")]
            Node[emphasis]
                Node[text("a")]
            Node[text(" ")]
            Node[strong]
                Node[text("simple")]
            Node[text(" ")]
            Node[internalLink("parser")]
                Node[text("parser")]
            Node[text(" with a normal ")]
            Node[link("url")]
                Node[text("link")]
            Node[text(" test")]

        """

        expect(AST.treeString).to(equal(expectedResult))
    }

//    func testParser2() {
//        let string = "Even if people WFH..., it\'s safe to assume that a significant % is not working at all or much less than the usual. Yet, our basic needs are met. What does it say about the real utility of their job? => Note : Appealing idea, however not all our needs are basic, unless we\'re happy to live ever after in a confined world where entertainment = TV, shopping = Amazon, social = Zoom/none, etc. Of course the situation underlines the uselessness of SOME jobs, but it would be a stretch to generalize."
//
//        let parser = Parser(inputString: string)
//        let AST = parser.parseAST()
//    }

//    func testParser3() {
//        let string = "[The right to useful unemployment](https://www.ica.art/sites/default/files/downloads/Ivan%20Illich_%20The%20Right%20to%20Useful%20Unemployment.pdf) & [Energy and equity](http://www.davidtinapple.com/illich/1973_energy_equity.html) [[Illich]]"
//
//        let parser = Parser(inputString: string)
//        let AST = parser.parseAST()
//    }

//    func testParser4() {
//        let string = "=> real utility of their job?\n=> Note : Appealing idea, however not all our needs are basic, unless we\'re happy to live ever after in a confined world where entertainment = TV,\nshopping = Amazon\nsocial = Zoom/none, etc. Of course the situation underlines the uselessness of SOME jobs, but it would be a stretch to generalize."
//
//        let parser = Parser(inputString: string)
//        let AST = parser.parseAST()
//    }

//    func testParser5() {
//        let string = "# real utility\n## Note Appealing"
//
//        let parser = Parser(inputString: string)
//        let AST = parser.parseAST()
//        Logger.shared.logDebug("AST: \(AST.treeString)")
//    }

//    func testParser6() {
//        let string = "\u{10}"
//
//        let parser = Parser(inputString: string)
//        let AST = parser.parseAST()
//        Logger.shared.logDebug("AST: \(AST.treeString)")
//    }

//    func testParser7() {
//        let string = "[https://twitter.com/jcs/status/1291863596922806273?ref_src=twsrc%5Etfw%7Ctwcamp%5Etweetembed%7Ctwterm%5E1291863596922806273%7Ctwgr%5E%7Ctwcon%5Es1_&ref_url=https%3A%2F%2Ftwitframe.com%2Fshow%3Furl%3Dhttps3A2F2Ftwitter.com2Fjcs2Fstatus2F1291863596922806273conversation%3Dnone](https://twitter.com/jcs/status/1291863596922806273?ref_src=twsrc%5Etfw%7Ctwcamp%5Etweetembed%7Ctwterm%5E1291863596922806273%7Ctwgr%5E%7Ctwcon%5Es1_&ref_url=https%3A%2F%2Ftwitframe.com%2Fshow%3Furl%3Dhttps3A2F2Ftwitter.com2Fjcs2Fstatus2F1291863596922806273conversation%3Dnone)"
//
//        let parser = Parser(inputString: string)
//        let AST = parser.parseAST()
//        Logger.shared.logDebug("AST: \(AST.treeString)")
//    }

    func testParserTask() {
        let string = "- [x]Test of checked task\n- [ ]Test of unchecked task"
        let parser = Parser(inputString: string)
        let AST = parser.parseAST()
        let expectedResult = """
        Node[text("")]
            Node[check(true)]
                Node[text("Test of checked task")]
            Node[text("\\n")]
            Node[check(false)]
                Node[text("Test of unchecked task")]

        """
        expect(AST.treeString).to(equal(expectedResult))
    }
}

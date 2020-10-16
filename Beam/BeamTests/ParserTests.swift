//
//  ParserTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 13/10/2020.
//

import Foundation
import XCTest
@testable import Beam

class ParserTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testParser1() {
        let string = "Test of _a_ **simple** [[parser]] with a normal [link](url) test"
        let parser = Parser(inputString: string)
        let AST = parser.parseAST()

        print("AST:\n\(AST.treeString)")

        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        let str = visitor.visit(AST)
        print("attributed string: \(str)")

    }

    func testParser2() {
        let string = "Even if people WFH..., it\'s safe to assume that a significant % is not working at all or much less than the usual. Yet, our basic needs are met. What does it say about the real utility of their job? => Note : Appealing idea, however not all our needs are basic, unless we\'re happy to live ever after in a confined world where entertainment = TV, shopping = Amazon, social = Zoom/none, etc. Of course the situation underlines the uselessness of SOME jobs, but it would be a stretch to generalize. "

        let parser = Parser(inputString: string)
        let AST = parser.parseAST()

        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        let str = visitor.visit(AST)
        print("attributed string: \(str)")
    }

    func testParser3() {
        let string = "[The right to useful unemployment](https://www.ica.art/sites/default/files/downloads/Ivan%20Illich_%20The%20Right%20to%20Useful%20Unemployment.pdf) & [Energy and equity](http://www.davidtinapple.com/illich/1973_energy_equity.html) [[Illich]]"

        let parser = Parser(inputString: string)
        let AST = parser.parseAST()

        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        let str = visitor.visit(AST)
        print("attributed string: \(str)")
    }

    func testParser4() {
        let string = "=> real utility of their job?\n=> Note : Appealing idea, however not all our needs are basic, unless we\'re happy to live ever after in a confined world where entertainment = TV,\nshopping = Amazon\nsocial = Zoom/none, etc. Of course the situation underlines the uselessness of SOME jobs, but it would be a stretch to generalize."

        let parser = Parser(inputString: string)
        let AST = parser.parseAST()

        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        let str = visitor.visit(AST)
        print("attributed string: \(str)")
    }

    func testParser5() {
        let string = "# real utility\n## Note Appealing"

        let parser = Parser(inputString: string)
        let AST = parser.parseAST()
        print("AST: \(AST.treeString)")

        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        let str = visitor.visit(AST)
        print("attributed string: \(str)")
    }
}

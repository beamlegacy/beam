//
//  LexerTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 13/10/2020.
//

import Foundation
import XCTest
@testable import Beam

class LexerTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testLexer1() {
        let string1 = "Test of _a_ **simple** [[lexer]]"
        let lexer = Lexer(inputString: string1)

        let results: [(String, Lexer.TokenType)] = [
            ("Test", .Text),
            (" ", .Blank),
            ("of", .Text),
            (" ", .Blank),
            ("_", .Emphasis),
            ("a", .Text),
            ("_", .Emphasis),
            (" ", .Blank),
            ("**", .Strong),
            ("simple", .Text),
            ("**", .Strong),
            (" ", .Blank),
            ("[[", .LinkStart),
            ("lexer", .Text),
            ("]]", .LinkEnd),
            ("", .EndOfFile)
        ]

        for e in results {
            let token = lexer.nextToken()
//            print("new token: \(token)")
            XCTAssertEqual(e.0, token.string)
            XCTAssertEqual(e.1, token.type)
        }
    }

    func testLexer2() {
        let string1 = "Test of _a_\n**simple** [[lexer]]"
        let lexer = Lexer(inputString: string1)

        let results: [(String, Lexer.TokenType)] = [
            ("Test", .Text),
            (" ", .Blank),
            ("of", .Text),
            (" ", .Blank),
            ("_", .Emphasis),
            ("a", .Text),
            ("_", .Emphasis),
            ("\n", .NewLine),
            ("**", .Strong),
            ("simple", .Text),
            ("**", .Strong),
            (" ", .Blank),
            ("[[", .LinkStart),
            ("lexer", .Text),
            ("]]", .LinkEnd),
            ("", .EndOfFile)
        ]

        for e in results {
            let token = lexer.nextToken()
//            print("new token: \(token)")
            XCTAssertEqual(e.0, token.string)
            XCTAssertEqual(e.1, token.type)
        }
    }

    func testLexer3() {
        let string1 = "Test of **a**\n**simple** [[lexer]]"
        let lexer = Lexer(inputString: string1)

        let results: [(String, Lexer.TokenType)] = [
            ("Test", .Text),
            (" ", .Blank),
            ("of", .Text),
            (" ", .Blank),
            ("**", .Strong),
            ("a", .Text),
            ("**", .Strong),
            ("\n", .NewLine),
            ("**", .Strong),
            ("simple", .Text),
            ("**", .Strong),
            (" ", .Blank),
            ("[[", .LinkStart),
            ("lexer", .Text),
            ("]]", .LinkEnd),
            ("", .EndOfFile)
        ]

        for e in results {
            let token = lexer.nextToken()
//            print("new token: \(token)")
            XCTAssertEqual(e.0, token.string)
            XCTAssertEqual(e.1, token.type)
        }
    }

    func testLexer4() {
        let string1 = "]]yy"
        let lexer = Lexer(inputString: string1)

        let results: [(String, Lexer.TokenType)] = [
            ("]]", .LinkEnd),
            ("yy", .Text),
            ("", .EndOfFile)
        ]

        for e in results {
            let token = lexer.nextToken()
//            print("new token: \(token)")
            XCTAssertEqual(e.0, token.string)
            XCTAssertEqual(e.1, token.type)
        }
    }

    func testLexer5() {
        let string1 = "y"
        let lexer = Lexer(inputString: string1)

        let results: [(String, Lexer.TokenType)] = [
            ("y", .Text),
            ("", .EndOfFile)
        ]

        for e in results {
            let token = lexer.nextToken()
//            print("new token: \(token)")
            XCTAssertEqual(e.0, token.string)
            XCTAssertEqual(e.1, token.type)
        }
    }

    func testLexer6() {
        let string1 = "y\n"
        let lexer = Lexer(inputString: string1)

        let results: [(String, Lexer.TokenType)] = [
            ("y", .Text),
            ("\n", .NewLine),
            ("", .EndOfFile)
        ]

        for e in results {
            let token = lexer.nextToken()
//            print("new token: \(token)")
            XCTAssertEqual(e.0, token.string)
            XCTAssertEqual(e.1, token.type)
        }
    }
}

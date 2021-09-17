//
//  HtmlNoteAdapterPerformanceTests.swift
//  BeamTests
//
//  Created by Stef Kors on 17/09/2021.
//

import  Nimble
import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class HtmlNoteAdapterPerformanceTests: XCTestCase {
    let html = """
        <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
                <p>Lorem ipsum dolor sit amet consectetur adipisicing elit. Repudiandae, <a href="https://fr.wikipedia.org/wiki/Test_(psychologie)">Wikipédia</a> culpa, consequuntur earum aspernatur eum dolorem doloremque autem quisquam ut quis similique, ea placeat. Nulla temporibus dolorem vitae consequuntur consequatur blanditiis!</p>
        """

    func testArrayBeamElement() throws {
        let htmlNoteAdapter = HtmlNoteAdapter(URL(string: "http://test.com")!)
        self.measure {
            let _: [BeamElement] = htmlNoteAdapter.convert(html: html)
        }
    }

    func testSingleBeamElment() throws {
        let htmlNoteAdapter = HtmlNoteAdapter(URL(string: "http://test.com")!)
        self.measure {
            let _: BeamElement = htmlNoteAdapter.convert(html: html)
        }
    }


    func testString() throws {
        let htmlNoteAdapter = HtmlNoteAdapter(URL(string: "http://test.com")!)
        self.measure {
            let _: String = htmlNoteAdapter.convert(html: html)
        }
    }}

//
//  FakeNoteGeneratorTests.swift
//  BeamCoreTests
//
//  Created by Sebastien Metrot on 20/07/2021.
//

import XCTest
import Foundation
@testable import BeamCore
@testable import Beam

class fakeNoteGeneratorTests: XCTestCase {
    func testGenerator1() {
        let generator = FakeNoteGenerator(count: 5, journalRatio: 0.5, futureRatio: 0)
        generator.generateNotes()
        XCTAssertEqual(5, generator.notes.count)
    }

}

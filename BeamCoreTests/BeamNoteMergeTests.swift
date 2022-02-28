//
//  BeamNoteMergeTests.swift
//  BeamCoreTests
//
//  Created by Sebastien Metrot on 17/02/2022.
//

import XCTest
@testable import BeamCore

class BeamNoteMergeTests: XCTestCase {

    func mainResourcesPath() throws -> String {
        try XCTUnwrap(Bundle(for: type(of: self)).resourcePath)
    }

    func scenariosPath() throws -> String {
        URL(fileURLWithPath: "BeamNoteMerge", relativeTo: URL(fileURLWithPath: try mainResourcesPath())).path
    }

    func scenarios() throws -> [String] {
        (try FileManager.default.contentsOfDirectory(atPath: scenariosPath())).sorted()
    }

    func URLFor(scenario: String) throws -> URL {
        URL(fileURLWithPath: scenario, relativeTo: URL(fileURLWithPath: try scenariosPath()))
    }

    func note(_ filename: String, forScenario scenario: String) throws -> BeamNote {
        let path = URL(fileURLWithPath: filename, relativeTo: try URLFor(scenario: scenario))
        let data = try Data(contentsOf: path)
        let decoder = JSONDecoder()
        return try decoder.decode(BeamNote.self, from: data)
    }

    // swiftlint:disable:next large_tuple
    func notesFor(scenario: String) throws -> (ancestor: BeamNote, noteA: BeamNote, noteB: BeamNote, result: BeamNote) {
        return (ancestor: try note("ancestor.json", forScenario: scenario),
                noteA: try note("noteA.json", forScenario: scenario),
                noteB: try note("noteB.json", forScenario: scenario),
                result: try note("result.json", forScenario: scenario))
    }

    func runScenario(_ scenario: String) throws {
        try XCTContext.runActivity(named: "BeamNoteMerge.\(scenario)") { _ in
            let (ancestor, noteA, noteB, result) = try notesFor(scenario: scenario)
            noteA.merge(other: noteB, ancestor: ancestor, advantageOther: false)
            if scenario.contains("[fail]") {
                XCTAssertNotEqual(noteA.joinTexts, result.joinTexts, "scenario \(scenario) failed")
            } else {
                XCTAssertEqual(noteA.joinTexts, result.joinTexts, "scenario \(scenario) failed")
            }
        }
    }

    func testRunAllScenarios() throws {
        for scenario in try scenarios() {
            XCTAssertNoThrow(try runScenario(scenario))
        }
    }
}

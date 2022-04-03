//
//  MessagePackTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 22/09/2021.
//

import XCTest
import Nimble
import Foundation
import Combine
import MessagePack
@testable import BeamCore
@testable import Beam

class messagePackTests: XCTestCase {
    func testMessagePack1() {
        let encoder = MessagePackEncoder()
        guard let data = try? encoder.encode(Airport.example) else {
            XCTFail("Failed to encode Airport to messagePack data")
            return
        }
        let decoder = MessagePackDecoder()
        guard let decodedNote = try? decoder.decode(Airport.self, from: data) else {
            XCTFail("Failed to decode Airport from messagePack data")
            return
        }
        XCTAssertEqual(Airport.example, decodedNote)
    }

    func testMessagePack2() {
        let generator = FakeNoteGenerator(count: 1, journalRatio: 0, futureRatio: 0)
        generator.generateNotes()
        guard let note = generator.notes.first else {
            XCTFail("Failed to generate one fake note")
            return
        }

        let encoder = MessagePackEncoder()
        guard let data = try? encoder.encode(note) else {
            XCTFail("Failed to encode BeamNote to messagePack data")
            return
        }
        let decoder = MessagePackDecoder()
        guard let decodedNote = try? decoder.decode(BeamNote.self, from: data) else {
            XCTFail("Failed to decode BeamNote to messagePack data")
            return
        }
    }

    func testMessagePack3() {
        do {
            let testerB = TesterB()

            let encoder = MessagePackEncoder()
            let data = try encoder.encode(testerB)

            let decoder = MessagePackDecoder()
            let decoded = try decoder.decode(TesterB.self, from: data)

            XCTAssertEqual(testerB, decoded)
        } catch {
            return
        }
    }
}

class TesterA: Codable, Equatable {
    static func == (lhs: TesterA, rhs: TesterA) -> Bool {
        lhs.fun == rhs.fun
    }

    var fun = 1
}

class TesterB: TesterA {
    enum CodingKeys: CodingKey {
        case foo
    }
    var foo = 42

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(foo, forKey: .foo)
        try super.encode(to: encoder)
    }

    static func == (lhs: TesterB, rhs: TesterB) -> Bool {
        lhs.foo == rhs.foo && lhs.fun == rhs.fun
    }
}

struct Airport: Codable, Equatable {
    let name: String
    let iata: String
    let icao: String
    let coordinates: [Double]

    struct Runway: Codable, Equatable {
        enum Surface: String, Codable, Equatable {
            case rigid, flexible, gravel, sealed, unpaved, other
        }

        let direction: String
        let distance: Int
        let surface: Surface
    }

    let runways: [Runway]

    let instrumentApproachProcedures: [String]

    static var example: Airport {
        return Airport(
            name: "Portland International Airport",
            iata: "PDX",
            icao: "KPDX",
            coordinates: [-122.5975,
                          45.5886111111111],
            runways: [
                Airport.Runway(
                    direction: "3/21",
                    distance: 1829,
                    surface: .flexible
                )
            ],
            instrumentApproachProcedures: [
                "HI-ILS OR LOC RWY 28",
                "HI-ILS OR LOC/DME RWY 10",
                "ILS OR LOC RWY 10L",
                "ILS OR LOC RWY 10R",
                "ILS OR LOC RWY 28L",
                "ILS OR LOC RWY 28R",
                "ILS RWY 10R (SA CAT I)",
                "ILS RWY 10R (CAT II - III)",
                "RNAV (RNP) Y RWY 28L",
                "RNAV (RNP) Y RWY 28R",
                "RNAV (RNP) Z RWY 10L",
                "RNAV (RNP) Z RWY 10R",
                "RNAV (RNP) Z RWY 28L",
                "RNAV (RNP) Z RWY 28R",
                "RNAV (GPS) X RWY 28L",
                "RNAV (GPS) X RWY 28R",
                "RNAV (GPS) Y RWY 10L",
                "RNAV (GPS) Y RWY 10R",
                "LOC/DME RWY 21",
                "VOR-A",
                "HI-TACAN RWY 10",
                "TACAN RWY 28",
                "COLUMBIA VISUAL RWY 10L/",
                "MILL VISUAL RWY 28L/R"
            ]
        )
    }
}

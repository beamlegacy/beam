//
//  String+SearchTests.swift
//  BeamCoreTests
//
//  Created by Ludovic Ollagnier on 06/10/2021.
//

import XCTest
@testable import BeamCore

class StringSearchTests: XCTestCase {

    func testSearchSingleWord() {

        let stringToSearch = """
            A transporter is a fictional teleportation machine used in the Star Trek science fiction franchise. Transporters allow for teleportation by converting a person or object into an energy pattern (a process called "dematerialization"), then send ("beam") it to a target location or else return it to the transporter, where it is reconverted into matter ("rematerialization").
            """

        let found = stringToSearch.countInstances(of: "teleportation")
        XCTAssertTrue(found.count == 2)
    }

    func testSearchLongSearch() {
        let stringToSearch = """
            A transporter is a fictional teleportation machine used in the Star Trek science fiction franchise. Transporters allow for teleportation by converting a person or object into an energy pattern (a process called "dematerialization"), then send ("beam") it to a target location or else return it to the transporter, where it is reconverted into matter ("rematerialization").
            """

        let found = stringToSearch.countInstances(of: "Transporters allow for teleportation by converting a person or object into an energy pattern")
        XCTAssertTrue(found.count == 1)
    }

    func testSearchCaseInsensitive() {
        let stringToSearch = """
            A transporter is a fictional teleportation machine used in the Star Trek science fiction franchise. Transporters allow for teleportation by converting a person or object into an energy pattern (a process called "dematerialization"), then send ("beam") it to a target location or else return it to the transporter, where it is reconverted into matter ("rematerialization").
            """

        let found = stringToSearch.countInstances(of: "deMatEriaLizatioN")
        XCTAssertTrue(found.count == 1)
    }

    func testSearchDiacriticInsensitive() {
        let stringToSearch = "Le téléporteur (parfois appelé transporteur) est probablement le gadget technologique le plus emblématique de l'univers de science-fiction de Star Trek, en effet, c'est la seule série à avoir fait de la téléportation un moyen de transport courant. Ça en jette."

        let found1 = stringToSearch.countInstances(of: "téléporteur")
        let found2 = stringToSearch.countInstances(of: "Ça")
        XCTAssertTrue(found1.count == 1)
        XCTAssertTrue(found2.count == 1)
    }

    func testSearchTouchingWords() {
        let stringToSearch = "beambeam beambeam"

        let found = stringToSearch.countInstances(of: "beam")
        XCTAssertTrue(found.count == 4)
    }

    func testSearchLocation() {
        let stringToSearch = """
            A transporter is a fictional teleportation machine used in the Star Trek science fiction franchise. Transporters allow for teleportation by converting a person or object into an energy pattern (a process called "dematerialization"), then send ("beam") it to a target location or else return it to the transporter, where it is reconverted into matter ("rematerialization").
            """

        let found = stringToSearch.countInstances(of: "transporter")
        let expectRanges = [NSRange(location: 2, length: 11), NSRange(location: 100, length: 11), NSRange(location: 301, length: 11)]
        XCTAssertEqual(expectRanges, found)
    }
}

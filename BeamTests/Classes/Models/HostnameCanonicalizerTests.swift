//
//  HostnameCanonicalizerTests.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 28/03/2022.
//

import XCTest

@testable import Beam

class HostnameCanonicalizerTests: XCTestCase {
    func testCanonicalizedNames() {
        let canonicalizer = HostnameCanonicalizer.shared
        XCTAssertEqual(canonicalizer.canonicalHostname(for: "idmsa.apple.com"), "apple.com")
        XCTAssertNil(canonicalizer.canonicalHostname(for: "mypersonalpage.medium.com"))
    }

    func testHostsSharingCredentials() throws {
        let canonicalizer = HostnameCanonicalizer.shared
        XCTAssertNil(canonicalizer.hostsSharingCredentials(with: "beamapp.co"))
        let sharedWithAirbnb = try XCTUnwrap(canonicalizer.hostsSharingCredentials(with: "airbnb.fr"))
        XCTAssertTrue(sharedWithAirbnb.contains("airbnb.fr"))
        XCTAssertTrue(sharedWithAirbnb.contains("airbnb.co.nz"))
        XCTAssertFalse(sharedWithAirbnb.contains("airnewzealand.co.nz"))
        let sharedWithAppannie = try XCTUnwrap(canonicalizer.hostsSharingCredentials(with: "appannie.com"))
        XCTAssertTrue(sharedWithAppannie.contains("appannie.com"))
        XCTAssertTrue(sharedWithAppannie.contains("data.ai"))
        XCTAssertFalse(sharedWithAppannie.contains("airnewzealand.co.nz"))
    }
}

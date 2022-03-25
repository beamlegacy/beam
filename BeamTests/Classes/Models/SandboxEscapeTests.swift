//
//  SandboxEscapeTests.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 18/03/2022.
//

import XCTest

@testable import Beam

class SandboxEscapeTests: XCTestCase {
    func testNonexistentFilesAreRemovedFromGroup() throws {
        let bundle = Bundle(for: type(of: self))
        let mainURL = try XCTUnwrap(bundle.url(forResource: "safariHistory", withExtension: "db"))
        let fileGroup = SandboxEscape.FileGroup(mainFile: mainURL, dependentFiles: ["safariHistory.db-shm", "safariHistory.db-wal", "safariHistory.nonexistent"])
        let endorsedGroup = try XCTUnwrap(SandboxEscape.endorsedGroup(for: fileGroup))
        XCTAssertEqual(endorsedGroup.mainFile, mainURL)
        XCTAssertEqual(endorsedGroup.dependentFiles, ["safariHistory.db-shm", "safariHistory.db-wal"])
    }

    func testTemporaryCopy() throws {
        func assertTemporaryFilesExist(provider: URLProvider?) throws {
            let temporaryCopy = try XCTUnwrap(provider)
            XCTAssertNotEqual(temporaryCopy.wrappedURL, mainURL)
            withExtendedLifetime(temporaryCopy) {
                XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("safariHistory.db").path))
                XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("safariHistory.db-shm").path))
                XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("safariHistory.db-wal").path))
            }
        }
        let bundle = Bundle(for: type(of: self))
        let mainURL = try XCTUnwrap(bundle.url(forResource: "safariHistory", withExtension: "db"))
        let fileGroup = SandboxEscape.FileGroup(mainFile: mainURL, dependentFiles: ["safariHistory.db-shm", "safariHistory.db-wal"])
        var temporaryCopy = SandboxEscape.TemporaryCopy(group: fileGroup)
        let temporaryDirectory = try XCTUnwrap(temporaryCopy?.wrappedURL.deletingLastPathComponent())
        try assertTemporaryFilesExist(provider: temporaryCopy)
        temporaryCopy = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("safariHistory.db").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("safariHistory.db-shm").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("safariHistory.db-wal").path))
    }
}

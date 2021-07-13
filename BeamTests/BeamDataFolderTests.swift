//
//  BeamDataFolderTests.swift
//  BeamTests
//
//  Created by Jean-Louis Darmon on 02/07/2021.
//

import XCTest

@testable import Beam
class BeamDataFolderTests: XCTestCase {
    var dataFolderStr: String = ""

    override func setUp() {
        super.setUp()
        dataFolderStr = BeamData.dataFolder(fileName: "")

        let homeFolder = FileManager.default.homeDirectoryForCurrentUser
        dataFolderStr = homeFolder.path
        dataFolderStr.append("/Library/Application Support/Beam/")
        dataFolderStr.append("BeamData-\(Configuration.env)")

        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            dataFolderStr.append("-\(jobId)")
        }
    }

    func testDataFolder() {
        XCTAssertEqual(BeamData.dataFolder(fileName: ""), "\(dataFolderStr)/", "DataFolder Path is wrong")
    }
}

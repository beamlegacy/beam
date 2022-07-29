//
//  BeamObjectManagerTests.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 29/07/2022.
//

import Foundation
import XCTest
@testable import Beam

class BeamObjectManagerTests: XCTestCase {

    func testUploadType() {
        let savedDirectUploadAllObjects = Configuration.directUploadAllObjects
        defer {
            Configuration.directUploadAllObjects = savedDirectUploadAllObjects
        }

        Configuration.directUploadAllObjects = true
        XCTAssertEqual(BeamFileDBManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(BrowsingTreeStoreManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(GRDBNoteFrecencyStorage.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(TabGroupingStoreManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(PrivateKeySignatureManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(PasswordManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(BeamLinkDB.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(ContactsManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(BeamDocumentSynchronizer.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(BeamDatabaseSynchronizer.uploadType, BeamObjectRequestUploadType.directUpload)

        Configuration.directUploadAllObjects = false
        XCTAssertEqual(BeamFileDBManager.uploadType, BeamObjectRequestUploadType.directUpload, "Files shoud be sent to s3 by default")
        XCTAssertEqual(BrowsingTreeStoreManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(GRDBNoteFrecencyStorage.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(TabGroupingStoreManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(PrivateKeySignatureManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(PasswordManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(BeamLinkDB.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(ContactsManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(BeamDocumentSynchronizer.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(BeamDatabaseSynchronizer.uploadType, BeamObjectRequestUploadType.multipartUpload)
    }

}

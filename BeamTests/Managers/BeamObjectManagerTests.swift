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
        XCTAssertEqual(BeamFileDBManager.uploadType, BeamObjectRequestUploadType.directUpload)
        XCTAssertEqual(BrowsingTreeStoreManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(GRDBNoteFrecencyStorage.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(TabGroupingStoreManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(PrivateKeySignatureManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(PasswordManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(BeamLinkDB.uploadType, BeamObjectRequestUploadType.multipartUpload)
        XCTAssertEqual(ContactsManager.uploadType, BeamObjectRequestUploadType.multipartUpload)
    }

}

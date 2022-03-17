//
//  ChromiumPasswordDecryptionTests.swift
//  BeamTests
//
//  Created by Beam on 20/12/2021.
//

import XCTest
import Combine
@testable import Beam

class ChromiumPasswordDecryptionTests: XCTestCase {
    let keychainSecret = "tcP8S8jNViqvt6lYP6g9rA=="

    func testKeyDerivation() throws {
        let derivedKey = try ChromiumPasswordImporter.derivedKey(secret: keychainSecret)
        XCTAssertEqual(derivedKey, Data([0x03, 0xfe, 0xe5, 0x33, 0x9c, 0x26, 0x3e, 0x29, 0x27, 0x6b, 0x1e, 0xf3, 0xce, 0x59, 0x2b, 0xe8]))
    }

    func testPasswordDecryption() throws {
        let encryptedPassword = Data([0x76, 0x31, 0x30, 0x2e, 0xb7, 0x2c, 0x5b, 0x9a, 0x60, 0xe3, 0xd9, 0x10, 0x1d, 0x3f, 0xcb, 0x32, 0xba, 0x3b, 0x46])
        let derivedKey = Data([0x03, 0xfe, 0xe5, 0x33, 0x9c, 0x26, 0x3e, 0x29, 0x27, 0x6b, 0x1e, 0xf3, 0xce, 0x59, 0x2b, 0xe8])
        let decryptedPassword = try ChromiumPasswordImporter.decryptedPassword(for: encryptedPassword, using: derivedKey)
        XCTAssertEqual(String(data: decryptedPassword, encoding: .utf8), "testpassword")
    }

    func testImportingChromiumPasswordDatabase() throws {
        let bundle = Bundle(for: type(of: self))
        var subscriptions = Set<AnyCancellable>()
        let passwordsURL = try XCTUnwrap(bundle.url(forResource: "ChromiumLoginData", withExtension: "db"))
        let importer = ChromiumPasswordImporter(browser: .brave)
        let expectation = XCTestExpectation(description: "Chromium password import finished")
        var results = [BrowserPasswordResult]()
        importer.passwordsPublisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished: expectation.fulfill()
                case .failure(let error): XCTFail("Chromium password import failed: \(error)")
                }
            },
            receiveValue: { result in
                results.append(result)
            })
        .store(in: &subscriptions)
        try importer.importPasswords(from: [passwordsURL], keychainSecret: keychainSecret)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].itemCount, 1)
        XCTAssertEqual(results[0].item.url, URL(string: "https://ssl.imoof.com/menu_test.html"))
        XCTAssertEqual(results[0].item.username, "testlogin")
        XCTAssertEqual(String(data: results[0].item.password, encoding: .utf8), "testpassword")
        XCTAssertEqual(results[0].item.dateCreated?.description, "2021-12-17 18:09:00 +0000")
        XCTAssertEqual(results[0].item.dateLastUsed?.description, "2021-12-17 18:08:31 +0000")
    }
}

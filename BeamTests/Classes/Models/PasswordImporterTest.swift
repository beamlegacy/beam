//
//  PasswordImporterTest.swift
//  BeamTests
//
//  Created by Beam on 12/07/2021.
//

import XCTest

@testable import Beam

class PasswordImporterTest: XCTestCase {
    override func setUp() {
        super.setUp()
        BeamTestsHelper.logout()
        PasswordManager.shared.markDeleted(hostname: "test1.com", for: "user1")
        PasswordManager.shared.markDeleted(hostname: "test2.com", for: "user2")
        PasswordManager.shared.markDeleted(hostname: "test3.com", for: "user3")
        PasswordManager.shared.markDeleted(hostname: "test4.com", for: "user4")
        PasswordManager.shared.markDeleted(hostname: "test5.com", for: "user5")
        PasswordManager.shared.markDeleted(hostname: "test6.com", for: "user6")
    }

    func testValidCSVCanBeImported() throws {
        let csv = """
            url,username,password
            http://test1.com,user1,pass1
            "http://test2.com","user2","pass2"
            """
        try PasswordImporter.importPasswords(fromCSV: csv)
        let expectation1 = expectation(description: "Expect password request returns.")
        let password = PasswordManager.shared.password(hostname: "test1.com", username: "user1")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = PasswordManager.shared.password(hostname: "test2.com", username: "user2")
        XCTAssertEqual(passwordTwo, "pass2")
        expectation2.fulfill()

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Retrieving imported password failed with: \(String(describing: error))")
        }
    }

    func testValidCSVWithOutOfOrderColumnsCanBeImported() throws {
        let csv = """
            dummy,Password,unused,URL,Username,test
            1,pass1,11,http://test1.com,user1,111
            "2","pass2","22","http://test2.com","user2","222"
            """
        try PasswordImporter.importPasswords(fromCSV: csv)
        let expectation1 = expectation(description: "Expect password request returns.")
        let password = PasswordManager.shared.password(hostname: "test1.com", username: "user1")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = PasswordManager.shared.password(hostname: "test2.com", username: "user2")
        XCTAssertEqual(passwordTwo, "pass2")
        expectation2.fulfill()

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Retrieving imported password failed with: \(String(describing: error))")
        }
    }

    func testValidCSVWithQuotesInFieldsCanBeImported() throws {
        let csv = #"""
            url,username,password
            "http://test1.com","""user1""","pass1"
            "http://test2.com","user2","pass""2"
            """#
        try PasswordImporter.importPasswords(fromCSV: csv)
        let expectation1 = expectation(description: "Expect password request returns.")
        let password = PasswordManager.shared.password(hostname: "test1.com", username: "\"user1\"")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = PasswordManager.shared.password(hostname: "test2.com", username: "user2")
        XCTAssertEqual(passwordTwo, "pass\"2")
        expectation2.fulfill()
        
        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Retrieving imported password failed with: \(String(describing: error))")
        }
    }

    func testCSVWithMissingHeadersThrows() throws {
        let csv = """
            dummy,unused,url,username,test
            1,11,http://test1.com,user1,111
            "2","22","http://test2.com","user2","222"
            """
        XCTAssertThrowsError(
            try PasswordImporter.importPasswords(fromCSV: csv),
            "A headerNotFound error should have been thrown."
        )
    }

    func testHostIsMinimized() throws {
        let csv = """
            url,username,password
            test1.com,user1,pass1
            http://test2.com,user2,pass2
            https://test3.com/,user3,pass3
            www.test4.com,user4,pass4
            http://www.test5.com/path,user5,pass5
            https://www.test6.com?key=value,user6,pass6
            """
        try PasswordImporter.importPasswords(fromCSV: csv)
        let expectation1 = expectation(description: "Expect password request returns.")
        let password = PasswordManager.shared.password(hostname: "test1.com", username: "user1")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = PasswordManager.shared.password(hostname: "test2.com", username: "user2")
        XCTAssertEqual(passwordTwo, "pass2")
        expectation2.fulfill()

        let expectation3 = expectation(description: "Expect password request returns.")
        let passwordThree = PasswordManager.shared.password(hostname: "test3.com", username: "user3")
        XCTAssertEqual(passwordThree, "pass3")
        expectation3.fulfill()

        let expectation4 = expectation(description: "Expect password request returns.")
        let passwordFour = PasswordManager.shared.password(hostname: "test4.com", username: "user4")
        XCTAssertEqual(passwordFour, "pass4")
        expectation4.fulfill()

        let expectation5 = expectation(description: "Expect password request returns.")
        let passwordFive = PasswordManager.shared.password(hostname: "test5.com", username: "user5")
        XCTAssertEqual(passwordFive, "pass5")
        expectation5.fulfill()

        let expectation6 = expectation(description: "Expect password request returns.")
        let passwordSix = PasswordManager.shared.password(hostname: "test6.com", username: "user6")
        XCTAssertEqual(passwordSix, "pass6")
        expectation6.fulfill()

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Retrieving imported password failed with: \(String(describing: error))")
        }
    }

    func testExistingPasswordIsUpdated() throws {
        let csv = """
            url,username,password
            test6.com,user6,pass1
            test6.com,user6,pass2
            test6.com,user6,pass3
            """
        try PasswordImporter.importPasswords(fromCSV: csv)
        let expectation1 = expectation(description: "Expect password request returns.")
        let entries = PasswordManager.shared.entries(for: "test6.com", exact: true)
        XCTAssertEqual(entries.count, 1)
        let password = PasswordManager.shared.password(hostname: "test6.com", username: "user6")
        XCTAssertEqual(password, "pass3")
        expectation1.fulfill()

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Retrieving imported password failed with: \(String(describing: error))")
        }
    }
}

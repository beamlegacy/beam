//
//  PasswordImporterTest.swift
//  BeamTests
//
//  Created by Beam on 12/07/2021.
//

import XCTest

@testable import Beam

class PasswordImporterTest: XCTestCase {

    var passwordManager: PasswordManager!

    override func setUpWithError() throws {
        passwordManager = PasswordManager()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testValidCSVCanBeImported() throws {
        let csv = """
            url,username,password
            http://test1.com,user1,pass1
            "http://test2.com","user2","pass2"
            """
        try PasswordImporter.importPasswords(fromCSV: csv)
        let expectation1 = expectation(description: "Expect password request returns.")
        let password = passwordManager.password(host: "test1.com", username: "user1")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = passwordManager.password(host: "test2.com", username: "user2")
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
        let password = passwordManager.password(host: "test1.com", username: "user1")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = passwordManager.password(host: "test2.com", username: "user2")
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
        let password = passwordManager.password(host: "test1.com", username: "\"user1\"")
        XCTAssertEqual(password, "pass1")
        expectation1.fulfill()

        let expectation2 = expectation(description: "Expect password request returns.")
        let passwordTwo = passwordManager.password(host: "test2.com", username: "user2")
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

}

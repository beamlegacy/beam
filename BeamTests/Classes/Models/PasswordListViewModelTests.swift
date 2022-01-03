//
//  PasswordListViewModelTests.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 21/12/2021.
//

import XCTest

@testable import Beam

class PasswordListViewModelTests: XCTestCase {
    var passwordManager: PasswordManager!

    override func setUp() {
        super.setUp()
        let passwordsDB = MockPasswordsDB()
        _ = try? passwordsDB.save(hostname: "test1.com", username: "user1", password: "password1", uuid: UUID())
        _ = try? passwordsDB.save(hostname: "test2.com", username: "user2", password: "password2", uuid: UUID())
        _ = try? passwordsDB.save(hostname: "test3.com", username: "user3", password: "password3", uuid: UUID())
        _ = try? passwordsDB.save(hostname: "test4.com", username: "user4", password: "password4", uuid: UUID())
        _ = try? passwordsDB.save(hostname: "test5.com", username: "user5", password: "password5", uuid: UUID())
        _ = try? passwordsDB.save(hostname: "test6.com", username: "user6", password: "password6", uuid: UUID())
        passwordManager = PasswordManager(passwordsDB: passwordsDB)
    }

    func testFilteringEntries() throws {
        let viewModel = PasswordListViewModel(passwordManager: passwordManager)
        XCTAssertEqual(viewModel.filteredPasswordEntries.count, 6)
        XCTAssertEqual(viewModel.selectedEntries.count, 0)
        viewModel.updateSelection(IndexSet([4, 5]))
        XCTAssertEqual(viewModel.selectedEntries.count, 2)
        viewModel.searchString = "test5"
        XCTAssertEqual(viewModel.filteredPasswordEntries.count, 1)
        XCTAssertEqual(viewModel.filteredPasswordEntries[0].minimizedHost, "test5.com")
    }
}

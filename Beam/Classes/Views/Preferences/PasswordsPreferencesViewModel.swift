//
//  PasswordsPreferencesViewModel.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 06/07/2021.
//

import Foundation
import Combine

class PasswordsPreferencesViewModel: ObservableObject {
    private var passwordManager = PasswordsManager()
    @Published var entries: [PasswordManagerEntry] = []

    init() {
        fetchAllEntries()
    }

    public func fetchAllEntries() {
        passwordManager.passwordsDB.fetchAll { [unowned self] entries in
            self.entries = entries
        }
    }
}

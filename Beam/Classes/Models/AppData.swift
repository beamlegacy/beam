//
//  AppData.swift
//  Beam
//
//  Created by Thomas on 26/08/2022.
//

import Foundation
import BeamCore

final class AppData: ObservableObject {
    static let shared = AppData()
    
    @Published private(set) var accounts = [BeamAccount]()
    // Will be removed for multi-account, avoid use if possible.
    @Published private(set) var currentAccount: BeamAccount?

    func account(for id: UUID) -> BeamAccount? {
        return accounts.first(where: { $0.id == id })
    }

    func addAccount(_ account: BeamAccount, setCurrent: Bool) throws {
        guard !accounts.contains(where: { $0.id != account.id }) else { return }
        accounts.append(account)
        if setCurrent {
            try setCurrentAccount(account)
        }
    }

    func setCurrentAccount(_ account: BeamAccount, database: BeamDatabase? = nil) throws {
        let database = database ?? account.defaultDatabase
        guard database.account == account else { throw BeamDataError.databaseAccountMismatch }
        if currentAccount != account {
            currentAccount = account
        }
        try account.setCurrentDatabase(database)
        AuthenticationManager.shared.account = currentAccount
        Persistence.Account.currentAccountId = account.id
    }

    func saveAccounts() throws {
        for account in accounts {
            try account.save()
        }
    }

    private func setupDefaultAccount() throws {
        assert(accounts.isEmpty)
        try addAccount(try createDefaultAccount(), setCurrent: true)
    }

    func createDefaultAccount() throws -> BeamAccount {
        let path = URL(fileURLWithPath: dataFolder(fileName: accountsFilename))
        let accountName = "Local"
        let id = UUID()
        let accountPath = path.appendingPathComponent("account-" + id.uuidString)
        let p = accountPath.path
        let account = try BeamAccount(id: id, email: "", name: accountName, path: p)
        account.getOrCreateDefaultDatabase()

        try account.save()

        return account
    }

    func setupCurrentAccount() throws {
        guard !accounts.isEmpty else {
            try setupDefaultAccount()
            return
        }

        guard let accountId = Persistence.Account.currentAccountId ?? accounts.first?.id else { throw BeamDataError.currentAccountNotSet }
        guard let dbId = Persistence.Account.currentDatabaseId ?? accounts.first?.defaultDatabaseId else { throw BeamDataError.currentDatabaseNotSet }

        guard let account = accounts.first(where: { $0.id == accountId }) ?? accounts.first else {
            throw BeamDataError.accountNotFound
        }

        let database = (try? account.loadDatabase(dbId)) ?? account.defaultDatabase
        try setCurrentAccount(account, database: database)
    }

    var accountsPath: URL {
        URL(fileURLWithPath: dataFolder(fileName: accountsFilename))
    }

    func loadAccounts() throws {
        let path = accountsPath
        Logger.shared.logInfo("Init accounts from \(path)")

        BeamAccount.loadAccounts(from: path).forEach { account in
            do {
                try addAccount(account, setCurrent: false)
            } catch {
                Logger.shared.logError("Unable to add account \(account): \(error)", category: .accountManager)
            }
        }
    }

    private func loadAccount(url: URL) throws {
        try addAccount(BeamAccount.load(fromFolder: url.path), setCurrent: false)
    }

    private var accountsFilename: String {
        var suffix = "-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for GRDB sqlite file: \(jobId)", category: .search)

            suffix += "-\(jobId)"
        }

        return "Accounts\(suffix)"
    }

    func clearAllAccounts() throws {
        try accounts.forEach {
            try $0.delete($0)
        }

        let url = URL(fileURLWithPath: dataFolder(fileName: accountsFilename))
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        accounts = []
        currentAccount?.data.currentDatabase = nil
        currentAccount?.data.currentDocumentCollection = nil
        currentAccount = nil

        try FileManager.default.removeItem(at: url)
        saveData()
    }

    func clearAllAccountsAndSetupDefaultAccount() throws {
        try clearAllAccounts()
        try setupCurrentAccount()

        currentAccount?.data.objectManager.setup()

        if let account = currentAccount {
            guard let db = currentAccount?.getOrCreateDefaultDatabase() else { return }
            try? setCurrentAccount(account, database: db)
        }
        saveData()
    }

    func checkAndRepairDB() {
        for account in accounts {
            account.checkAndRepairIntegrity()
        }
    }

    func saveData() {
        currentAccount?.data.saveData()
        try? saveAccounts()
    }

    func dataFolder() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)

        var name = "BeamData-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for dataFolder: \(jobId)", category: .general)
            name += "-\(jobId)"
        }

        guard let directory = paths.first else {
            // Never supposed to happen
            return "~/Application Data/BeamApp/"
        }

        let localDirectory = directory + "/Beam" + "/\(name)/"

        return localDirectory
    }

    func dataFolder(fileName: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)

        var name = "BeamData-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for dataFolder: \(jobId)", category: .general)
            name += "-\(jobId)"
        }

        guard let directory = paths.first else {
            // Never supposed to happen
            return "~/Application Data/BeamApp/"
        }

        let localDirectory = directory + "/Beam" + "/\(name)/"

        var destinationName = fileName
        if destinationName.hasPrefix("Beam/") {
            destinationName.removeFirst(5)
        }

        do {
            try FileManager.default.createDirectory(atPath: localDirectory,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)

            if !fileName.isEmpty, FileManager.default.fileExists(atPath: directory + "/\(fileName)") {
                do {
                    try FileManager.default.moveItem(atPath: directory + "/\(fileName)", toPath: localDirectory + destinationName)
                } catch {
                    Logger.shared.logError("Unable to move item \(fileName) \(directory) to \(localDirectory): \(error)", category: .general)
                }
            }
            return localDirectory + destinationName
        } catch {
            // Does not generate error if directory already exist
            return directory + destinationName
        }
    }

    // MARK: Bridging with old model

    func allWindowsDidClose() {
        currentAccount?.data.allWindowsDidClose()
    }

    func setup() {
        currentAccount?.data.objectManager.setup()
    }

    func softDeleteBrowsingTreeStore() {
        currentAccount?.data.browsingTreeStoreManager.softDelete(olderThan: 60, maxRows: 20_000)
    }
}

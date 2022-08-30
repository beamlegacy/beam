//
//  BeamManagerHolder.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 22/05/2022.
//

import Foundation
import BeamCore

public protocol BeamManagerOwner: AnyObject {
    var objectManager: BeamObjectManager { get }

    func loadManagers(_ store: GRDBStore) throws
    func unloadManagers()
    func manager<T: BeamManager>(_ managerType: T.Type) throws -> T

    var managers: [UUID: BeamManager] { get set }

    static var registeredManagers: [BeamManager.Type] { get set }
    static func registerManager(_ manager: BeamManager.Type)

    func checkAndRepairIntegrity()
    func postMigrationSetup() throws

}

public extension BeamManagerOwner {
    func manager<T: BeamManager>(_ managerType: T.Type) throws -> T {
        guard let m = managers[managerType.id] as? T else {
            throw BeamDatabaseError.managerNotFound
        }
        return m
    }

    static func registerManager(_ manager: BeamManager.Type) {
        guard !registeredManagers.contains(where: { $0 == manager }) else { return }
        registeredManagers.append(manager)
    }

    func loadManagers(_ store: GRDBStore) throws {
        for managerType in Self.registeredManagers {
            do {
                managers[managerType.id] = try managerType.load(self, objectManager: objectManager, store: store)
            } catch {
                Logger.shared.logError("Unable to init manager \(managerType) from \(self) with store \(store)", category: .database)
            }
        }
    }

    func postMigrationSetup() throws {
        for manager in managers.values {
            try manager.postMigrationSetup()
        }
    }

    func unloadManagers() {
        managers.removeAll()
    }

    var isLoaded: Bool {
        !managers.isEmpty
    }

    func clearManagersDB() {
        for handler in managers.values.compactMap({ manager -> GRDBHandler? in manager as? GRDBHandler }) {
            try? handler.clear()
        }
    }
}

//
//  BeamManager.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 16/05/2022.
//

import Foundation
import GRDB
import BeamCore

public protocol BeamManager: AnyObject {
    static var id: UUID { get }
    static var name: String { get }
    /// The holder must be weak to prevent a retain cycle!
    var holder: BeamManagerOwner? { get }

    static func load(_ holder: BeamManagerOwner, objectManager: BeamObjectManager, store: GRDBStore) throws -> Self
    func unload() throws
    func postMigrationSetup() throws

    init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws
}

public extension BeamManager {
    var managerName: String { Self.name }

    static func load(_ holder: BeamManagerOwner, objectManager: BeamObjectManager, store: GRDBStore) throws -> Self {
        try Self(holder: holder, objectManager: objectManager, store: store)
    }

    func postMigrationSetup() throws {
    }

    func unload() throws {
    }
}

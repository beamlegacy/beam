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
    var holder: BeamManagerOwner? { get }

    static func load(_ holder: BeamManagerOwner, store: GRDBStore) throws -> Self
    func unload() throws
    func postMigrationSetup() throws

    init(holder: BeamManagerOwner?, store: GRDBStore) throws
}

public extension BeamManager {
    var managerName: String { Self.name }

    static func load(_ holder: BeamManagerOwner, store: GRDBStore) throws -> Self {
        try Self(holder: holder, store: store)
    }

    func postMigrationSetup() throws {
    }

    func unload() throws {
    }
}

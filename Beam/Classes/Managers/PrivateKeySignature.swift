//
//  PrivateKeySignature.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/06/2021.
//

import Foundation
import BeamCore
import UUIDKit

struct PrivateKeySignature: Codable, Identifiable, Hashable {
    static var beamObjectType: BeamObjectObjectType = .privateKeySignature

    var id: UUID = UUID()
    var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }
    var publicKey: String = "none"
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?

    func copy() -> PrivateKeySignature {
        var pks = PrivateKeySignature()
        pks.id = id
        pks.publicKey = publicKey
        pks.createdAt = createdAt
        pks.updatedAt = updatedAt
        pks.deletedAt = deletedAt
        return pks
    }
}

class PrivateKeySignatureManager {
    var privateKeySignature: PrivateKeySignature { PrivateKeySignature() }

    enum DistantKeyStatus {
        case valid
        case invalid
        case none
    }

    init() {}

    func distantKeyStatus() async throws -> DistantKeyStatus {
        .none
    }
}

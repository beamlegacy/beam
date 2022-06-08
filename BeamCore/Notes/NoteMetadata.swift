//
//  NoteMetadata.swift
//  BeamCore
//
//  Created by Jean-Louis Darmon on 27/05/2022.
//

import Foundation

public enum BulletPointType: String {
    case empty
    case regular
}

public struct NoteMetadata: Codable {
    enum CodingKeys: CodingKey {
        case bulletPointVisibility
    }

    public var bulletPointVisibility: BulletPointType?

    init() {}

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(bulletPointVisibility?.rawValue, forKey: .bulletPointVisibility)

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawBulletType = try container.decode(String.self, forKey: .bulletPointVisibility)
        if let bulletType = BulletPointType(rawValue: rawBulletType) {
            self.bulletPointVisibility = bulletType
        }
    }
}

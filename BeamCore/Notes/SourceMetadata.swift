//
//  SourceMetadata.swift
//  BeamCore
//
//  Created by Stef Kors on 25/11/2021.
//

import Foundation

public struct SourceMetadata: Codable, Equatable, Hashable {
    public var origin: Origin?
    public var title: String?

    public enum Origin: Codable, Equatable, Hashable {
        case remote(URL)
        case local(UUID)
    }

    public init(origin: Origin, title: String? = nil) {
        self.origin = origin
        self.title = title
    }

    public init(remote url: URL, title: String? = nil) {
        self.title = title
        self.origin = .remote(url)
    }

    public init(local uuid: UUID, title: String? = nil) {
        self.title = title
        self.origin = .local(uuid)
    }

    public init(string: String?, title: String? = nil) {
        self.title = title
        guard let string = string else { return }
        // String value can either be URL or UUID
        if let uuid = UUID(uuidString: string) {
            self.origin = .local(uuid)
        } else if let url = URL(string: string) {
            self.origin = .remote(url)
        }
    }
}

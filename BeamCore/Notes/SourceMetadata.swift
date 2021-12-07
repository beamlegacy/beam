//
//  SourceMetadata.swift
//  BeamCore
//
//  Created by Stef Kors on 25/11/2021.
//

import Foundation

public enum SourceMetadataError: Error {
    case typeNameUnknown(String)
    case failedToDecode(String, forKey: String)
}

/// Additional information about where an Beam Element originates from.
/// For example content collected by point and shoot could contain metadata
/// referencing the page url of where it's collected.
public struct SourceMetadata: Codable, Equatable, Hashable {
    public var origin: OriginalLocation?
    public var title: String?

    /// Type of source origin. For example external urls and local notes.
    public enum OriginalLocation: Codable, Equatable, Hashable {
        /// References a remote url
        case remote(URL)
        /// References a local note
        case local(UUID)

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case remote
            case local
        }

        // swiftlint:disable:next cyclomatic_complexity
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Compatibility: We went through multiple strategies to encode and decode the origin.
            // For backwards compatibility all strategies are still supported
            // v2 .local
            if let uuid = try? container.decodeIfPresent(UUID.self, forKey: .local) {
                self = .local(uuid)
                return
            }
            // v2 .remote
            if let url = try? container.decodeIfPresent(URL.self, forKey: .remote) {
                self = .remote(url)
                return
            }

            // v1 .local
            if let localDict = try? container.decodeIfPresent([String: UUID].self, forKey: .local),
                      let uuid = localDict.values.first {
                self = .local(uuid)
                return
            }
            // v1 .remote
            if let remoteDict = try? container.decodeIfPresent([String: URL].self, forKey: .remote),
                      let url = remoteDict.values.first {
                self = .remote(url)
                return
            }

            throw SourceMetadataError.failedToDecode("origin", forKey: "local and remote")
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .local(uuid):
                try container.encode(uuid, forKey: .local)
            case let .remote(url):
                try container.encode(url, forKey: .remote)
            }
        }
    }

    public init(origin: OriginalLocation, title: String? = nil) {
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

    public init(string: String? = nil, title: String? = nil) {
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

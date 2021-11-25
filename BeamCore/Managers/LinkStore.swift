//
//  LinkStore.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/12/2020.
//

import Foundation
import UUIDKit

public struct Link: Codable {
    enum CodingKeys: String, CodingKey {
        case url, title, createdAt, updatedAt, deletedAt
    }

    public var id: UUID = .null
    public var url: String
    public var title: String?

    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var previousChecksum: String?
    public var checksum: String?

    public init(url: String, title: String?, createdAt: Date = BeamDate.now, updatedAt: Date = BeamDate.now, deletedAt: Date? = nil, previousChecksum: String? = nil) {
        self.id = UUID.v5(name: url, namespace: .url)
        self.url = url
        self.title = title

        self.createdAt = createdAt
        self.updatedAt = updatedAt
self.deletedAt = deletedAt
    self.previousChecksum = previousChecksum
    }
}

public protocol LinkManager {
    func getLinks(matchingUrl url: String) -> [UUID: Link]
    func getOrCreateIdFor(url: String, title: String?) -> UUID
    func linkFor(id: UUID) -> Link?
    func visit(_ url: String, title: String?) -> Link
    func deleteAll() throws
    func isDomain(id: UUID) -> Bool
    func getDomainId(id: UUID) -> UUID?
    var allLinks: [Link] { get }
}

public class FakeLinkManager: LinkManager {
    public func getLinks(matchingUrl url: String) -> [UUID: Link] { [:] }
    public func getOrCreateIdFor(url: String, title: String?) -> UUID { UUID.null }
    public func linkFor(id: UUID) -> Link? { nil }
    public func visit(_ url: String, title: String?) -> Link { Link(url: url, title: title) }
    public func deleteAll() throws { }
    public func isDomain(id: UUID) -> Bool { false }
    public func getDomainId(id: UUID) -> UUID? { UUID.null }
    public var allLinks: [Link] { [] }
}

public class LinkStore: LinkManager {
    public static var shared = LinkStore(linkManager: FakeLinkManager())
    public var linkManager: LinkManager

    public init(linkManager: LinkManager) {
        self.linkManager = linkManager
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] { linkManager.getLinks(matchingUrl: url) }
    public func getOrCreateIdFor(url: String, title: String? = nil) -> UUID { linkManager.getOrCreateIdFor(url: url, title: title) }
    public func linkFor(id: UUID) -> Link? { linkManager.linkFor(id: id) }
    public func visit(_ url: String, title: String? = nil) -> Link { linkManager.visit(url, title: title) }
    public func isDomain(id: UUID) -> Bool { linkManager.isDomain(id: id) }
    public func getDomainId(id: UUID) -> UUID? { linkManager.getDomainId(id: id) }
    public func deleteAll() throws { try linkManager.deleteAll() }

    public static func linkFor(_ id: UUID) -> Link? {
        return shared.linkFor(id: id)
    }
    public static func visit(_ url: String, title: String? = nil) -> Link { shared.visit(url, title: title) }
    public static func getOrCreateIdFor(_ url: String, title: String? = nil) -> UUID { shared.getOrCreateIdFor(url: url, title: title) }

    public static func isInternalLink(id: UUID) -> Bool {
        guard let link = linkFor(id) else { return false }
        return isInternal(link: link.url)
    }

    public static func isInternal(link: String) -> Bool {
        guard let url = URL(string: link) else { return false }
        return url.scheme == "beam"
    }

    public var allLinks: [Link] { linkManager.allLinks }
}

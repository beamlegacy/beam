//
//  LinkStore.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/12/2020.
//

import Foundation
import UUIDKit

public struct Link: Codable {
    public var id: UUID
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
    func getIdFor(link: String) -> UUID?
    func createIdFor(link: String, title: String?) -> UUID
    func linkFor(id: UUID) -> Link?
    func visit(link: String, title: String?)
    func deleteAll() throws
    var allLinks: [Link] { get }
}

public class FakeLinkManager: LinkManager {
    public func getLinks(matchingUrl url: String) -> [UUID: Link] { [:] }
    public func getIdFor(link: String) -> UUID? { nil }
    public func createIdFor(link: String, title: String?) -> UUID { .null }
    public func linkFor(id: UUID) -> Link? { nil }
    public func visit(link: String, title: String?) { }
    public func deleteAll() throws { }
    public var allLinks: [Link] { [] }
}

public class LinkStore: LinkManager {
    public static var shared = LinkStore(linkManager: FakeLinkManager())
    public var linkManager: LinkManager

    public init(linkManager: LinkManager) {
        self.linkManager = linkManager
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] { linkManager.getLinks(matchingUrl: url) }
    public func getIdFor(link: String) -> UUID? { linkManager.getIdFor(link: link) }
    public func createIdFor(link: String, title: String? = nil) -> UUID { linkManager.createIdFor(link: link, title: title) }
    public func linkFor(id: UUID) -> Link? { linkManager.linkFor(id: id) }
    public func visit(link: String, title: String? = nil) { linkManager.visit(link: link, title: title) }
    public func deleteAll() throws { try linkManager.deleteAll() }
    public static func linkFor(_ id: UUID) -> Link? {
        return shared.linkFor(id: id)
    }

    public static func createIdFor(_ link: String, title: String?) -> UUID { shared.createIdFor(link: link, title: title) }
    public static func getIdFor(_ link: String) -> UUID? { shared.getIdFor(link: link) }

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

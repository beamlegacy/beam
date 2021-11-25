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
    func getIdFor(url: String) -> UUID?
    func createIdFor(url: String, title: String?) -> UUID
    func linkFor(id: UUID) -> Link?
    func visit(url: String, title: String?)
    func deleteAll() throws
    func isDomain(id: UUID) -> Bool?
    func getDomainId(id: UUID, networkCompletion: ((Result<Bool, Error>) -> Void)?) -> UUID?
    var allLinks: [Link] { get }
}

public class FakeLinkManager: LinkManager {
    public func getLinks(matchingUrl url: String) -> [UUID: Link] { [:] }
    public func getIdFor(url: String) -> UUID? { nil }
    public func createIdFor(url: String, title: String?) -> UUID { .null }
    public func linkFor(id: UUID) -> Link? { nil }
    public func visit(url: String, title: String?) { }
    public func deleteAll() throws { }
    public func isDomain(id: UUID) -> Bool? { nil }
    public func getDomainId(id: UUID, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> UUID? { nil }
    public var allLinks: [Link] { [] }
}

public class LinkStore: LinkManager {
    public static var shared = LinkStore(linkManager: FakeLinkManager())
    public var linkManager: LinkManager

    public init(linkManager: LinkManager) {
        self.linkManager = linkManager
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] { linkManager.getLinks(matchingUrl: url) }
    public func getIdFor(url: String) -> UUID? { linkManager.getIdFor(url: url) }
    public func createIdFor(url: String, title: String? = nil) -> UUID { linkManager.createIdFor(url: url, title: title) }
    public func linkFor(id: UUID) -> Link? { linkManager.linkFor(id: id) }
    public func visit(url: String, title: String? = nil) { linkManager.visit(url: url, title: title) }
    public func isDomain(id: UUID) -> Bool? { linkManager.isDomain(id: id) }
    public func getDomainId(id: UUID, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> UUID? { linkManager.getDomainId(id: id, networkCompletion: networkCompletion) }
    public func deleteAll() throws { try linkManager.deleteAll() }

    public static func linkFor(_ id: UUID) -> Link? {
        return shared.linkFor(id: id)
    }

    public static func createIdFor(_ url: String, title: String?) -> UUID { shared.createIdFor(url: url, title: title) }
    public static func getIdFor(_ url: String) -> UUID? { shared.getIdFor(url: url) }

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

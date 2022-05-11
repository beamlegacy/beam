//
//  LinkStore.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/12/2020.
//

import Foundation
import UUIDKit

public struct Link: Codable {
    public static let missing = Link(url: "<???>", title: nil, content: nil, createdAt: Date.distantPast, updatedAt: Date.distantPast)
    enum CodingKeys: String, CodingKey {
        case url, title, createdAt, frecencyVisitLastAccessAt, frecencyVisitScore, frecencyVisitSortScore, updatedAt, deletedAt
    }

    public var id: UUID = .null
    public var url: String
    public var title: String?
    public var content: String?
    public var destination: UUID?
    public var frecencyVisitLastAccessAt: Date?
    public var frecencyVisitScore: Float?
    public var frecencyVisitSortScore: Float?

    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(url: String, title: String?, content: String?, destination: UUID? = nil,
                frecencyVisitLastAccessAt: Date? = nil, frecencyVisitScore: Float? = nil,
                frecencyVisitSortScore: Float? = nil, createdAt: Date = BeamDate.now,
                updatedAt: Date = BeamDate.now, deletedAt: Date? = nil) {
        self.id = UUID.v5(name: url, namespace: .url)
        self.url = url
        self.title = title
        self.content = content
        self.destination = destination
        self.frecencyVisitLastAccessAt = frecencyVisitLastAccessAt
        self.frecencyVisitScore = frecencyVisitScore
        self.frecencyVisitSortScore = frecencyVisitSortScore

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public static let tableName = "Link"

    public mutating func setDestination(_ destination: String?) {
        if let destination = destination {
            self.destination = UUID.v5(name: destination, namespace: .url)
        } else {
            self.destination = nil
        }
    }
}

public protocol LinkManager {
    func getLinks(matchingUrl url: String) -> [UUID: Link]
    func getLinks(for ids: [UUID]) -> [UUID: Link]
    func getOrCreateId(for url: String, title: String?, content: String?, destination: String?) -> UUID
    func linkFor(id: UUID) -> Link?
    func visit(_ url: String, title: String?, content: String?, destination: String?) -> Link
    func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)?)
    func isDomain(id: UUID) -> Bool
    func getDomainId(id: UUID) -> UUID?
    func insertOrIgnore(links: [Link])
    var allLinks: [Link] { get }
}
extension LinkManager {
    public func normalized(url: String) -> String {
        URL(string: url)?.normalized.absoluteString ?? url
    }
    public func preprocess(title: String?) -> String? {
        title?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public func isDomain(id: UUID) -> Bool {
        guard let link = linkFor(id: id), URL(string: link.url)?.isDomain ?? false else { return false }
        return true
    }

    public func getDomainId(id: UUID) -> UUID? {
        guard let link = linkFor(id: id),
              let domain = URL(string: link.url)?.domain else { return nil }
        return getOrCreateId(for: domain.absoluteString, title: nil, content: nil, destination: nil)
    }
}

public class FakeLinkManager: LinkManager {
    public func getLinks(matchingUrl url: String) -> [UUID: Link] { [:] }
    public func getLinks(for ids: [UUID]) -> [UUID: Link] { [:] }
    public func getOrCreateId(for url: String, title: String?, content: String?, destination: String?) -> UUID { UUID.null }
    public func linkFor(id: UUID) -> Link? { nil }
    public func visit(_ url: String, title: String?, content: String?, destination: String?) -> Link { Link(url: url, title: title, content: content, destination: nil) }
    public func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)?) { }
    public func isDomain(id: UUID) -> Bool { false }
    public func getDomainId(id: UUID) -> UUID? { UUID.null }
    public func insertOrIgnore(links: [Link]) { }
    public var allLinks: [Link] { [] }
}

public class LinkStore: LinkManager {
    public static var shared = LinkStore(linkManager: FakeLinkManager())
    public var linkManager: LinkManager

    public init(linkManager: LinkManager) {
        self.linkManager = linkManager
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] { linkManager.getLinks(matchingUrl: url) }
    public func getLinks(for ids: [UUID]) -> [UUID: Link] { linkManager.getLinks(for: ids) }

    public func getOrCreateId(for url: String, title: String? = nil, content: String? = nil, destination: String? = nil) -> UUID {
        guard url != Link.missing.url else { return Link.missing.id }
        let normalizedUrl = normalized(url: url)
        let preprocessedTitle = preprocess(title: title)
        return linkManager.getOrCreateId(for: normalizedUrl, title: preprocessedTitle, content: content, destination: destination)
    }
    public func linkFor(id: UUID) -> Link? { linkManager.linkFor(id: id) }
    public func visit(_ url: String, title: String? = nil, content: String? = nil, destination: String? = nil) -> Link {
        guard url != Link.missing.url else { return Link.missing }
        let normalizedUrl = normalized(url: url)
        let preprocessedTitle = preprocess(title: title)
        return linkManager.visit(normalizedUrl, title: preprocessedTitle, content: content, destination: destination)
    }
    public func isDomain(id: UUID) -> Bool { linkManager.isDomain(id: id) }
    public func getDomainId(id: UUID) -> UUID? { linkManager.getDomainId(id: id) }
    public func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)?) {
        linkManager.deleteAll(includedRemote: includedRemote) { networkResult in
            networkCompletion?(networkResult)
        }
    }
    public func insertOrIgnore(links: [Link]) {
        linkManager.insertOrIgnore(links: links.filter { $0.id != Link.missing.id })
    }
    public static func linkFor(_ id: UUID) -> Link? {
        return shared.linkFor(id: id)
    }
    public static func visit(_ url: String, title: String? = nil, content: String? = nil) -> Link { shared.visit(url, title: title, content: content) }
    public static func getOrCreateIdFor(_ url: String, title: String? = nil, content: String? = nil) -> UUID { shared.getOrCreateId(for: url, title: title, content: content) }

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

public class InMemoryLinkManager: LinkManager {
    public func insertOrIgnore(links: [Link]) {
        for link in links where self.linksById[link.id] == nil {
            self.linksById[link.id] = link
        }
    }

    var linksById = [UUID: Link]()
    var linksByUrl = [String: Link]()

    public init() {}
    public func getLinks(matchingUrl url: String) -> [UUID: Link] {
        linksById.filter { $0.value.url.contains(url) }
    }
    public func getLinks(for ids: [UUID]) -> [UUID: Link] {
        linksById.filter { ids.contains($0.key) }
    }
    private func insert(link: Link) {
        linksById[link.id] = link
        linksByUrl[link.url] = link
    }

    public func getOrCreateId(for url: String, title: String?, content: String?, destination: String?) -> UUID {
        if let existing = linksByUrl[url] { return existing.id }
        let link = Link(url: url, title: title, content: content)
        insert(link: link)
        return link.id
    }

    public func linkFor(id: UUID) -> Link? {
        linksById[id]
    }

    public func visit(_ url: String, title: String?, content: String?, destination: String?) -> Link {
        var link: Link
        if let existing = linksByUrl[url] {
            link = existing
            if title?.isEmpty == false {
                link.title = title
            }
            link.content = content
            link.updatedAt = BeamDate.now
        } else {
            link = Link(url: url, title: title, content: content)
        }
        link.setDestination(destination)
        insert(link: link)
        return link
    }

    public func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)?) {
        linksById = [UUID: Link]()
    }

    public var allLinks: [Link] {
        Array(linksById.values)
    }
}

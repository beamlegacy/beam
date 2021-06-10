//
//  LinkStore.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/12/2020.
//

import Foundation

public struct Link: Codable {
    public var url: String
    public var visits: [Date]
    public var title: String?
}

public struct LinkStruct {
    public let bid: Int64
    public let url: String
    public let title: String?

    public init(bid: Int64, url: String, title: String?) {
        self.bid = bid
        self.url = url
        self.title = title
    }
}

public protocol LinkManagerBase {
    func loadLinks() -> [LinkStruct]
    func saveLink(_ linkStruct: LinkStruct, completion: ((Result<Bool, Error>) -> Void)?)
}

public class FakeLinkManager: LinkManagerBase {
    public func loadLinks() -> [LinkStruct] { return [] }
    public func saveLink(_ linkStruct: LinkStruct, completion: ((Result<Bool, Error>) -> Void)?) {
        //completion
    }
}

public class LinkStore: Codable {
    public var idGenerator = MonotonicIncreasingID64()
    public static var shared = LinkStore(linkManager: FakeLinkManager())
    public var linkManager: LinkManagerBase

    public private(set) var links = [UInt64: Link]()
    public private(set) var ids = [String: UInt64]()

    public init(linkManager: LinkManagerBase) {
        self.linkManager = linkManager
    }

    public func loadFromDB(linkManager: LinkManagerBase) -> Int {
        self.linkManager = linkManager
        let loadedLinks = linkManager.loadLinks()
        for link in loadedLinks {
            links[UInt64(bitPattern: link.bid)] = Link(url: link.url, visits: [])
        }
        return loadedLinks.count
    }

    required public init(from decoder: Decoder) throws {
        linkManager = FakeLinkManager()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        links = try container.decode([UInt64: Link].self, forKey: .links)
        for link in links {
            ids[link.value.url] = link.key
        }

        if container.contains(.idGenerator) {
            idGenerator = try container.decode(MonotonicIncreasingID64.self, forKey: .idGenerator)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(links, forKey: .links)
        try container.encode(idGenerator, forKey: .idGenerator)
    }

    enum CodingKeys: String, CodingKey {
        case links
        case idGenerator
    }

    public func getIdFor(link: String) -> UInt64? {
        guard let id = ids[link] else {
            return nil
        }

        return id
    }

    public func createIdFor(link: String, title: String? = nil) -> UInt64 {
        guard let id = getIdFor(link: link) else {
            let id = idGenerator.newValue()
            ids[link] = id
            links[id] = Link(url: link, visits: [], title: title)
            let linkStruct = LinkStruct(bid: Int64(bitPattern: id), url: link, title: title)
            linkManager.saveLink(linkStruct, completion: nil)
            return id
        }

        return id
    }

    public func linkFor(id: UInt64) -> Link? {
        guard let link = links[id] else {
            return nil
        }

        return link
    }

    public func visit(link: String, title: String? = nil) {
        let id = createIdFor(link: link, title: title)
        guard var linkStruct = linkFor(id: id) else {
            Logger.shared.logError("Unable to fetch Link Structure for link \(link)", category: .search)
            return
        }
        linkStruct.visits.append(Date())
        if let title = title {
            linkStruct.title = title
        }
        links[id] = linkStruct
    }

    public static func linkFor(_ id: UInt64) -> Link? {
        return shared.linkFor(id: id)
    }

    public static func createIdFor(_ link: String, title: String?) -> UInt64 {
        return shared.createIdFor(link: link, title: title)
    }

    public static func getIdFor(_ link: String) -> UInt64? {
        return shared.getIdFor(link: link)
    }

    public static func isInternalLink(id: UInt64) -> Bool {
        guard let link = linkFor(id) else { return false }
        return isInternal(link: link.url)
    }

    public static func isInternal(link: String) -> Bool {
        guard let url = URL(string: link) else { return false }
        return url.scheme == "beam"
    }

    public static func loadFrom(_ path: URL) throws {
        let decoder = JSONDecoder()
        shared = try decoder.decode(Self.self, from: Data(contentsOf: path))
    }

    public static func saveTo(_ path: URL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(shared)
        try data.write(to: path)
    }
}

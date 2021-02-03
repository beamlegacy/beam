//
//  LinkStore.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/12/2020.
//

import Foundation

struct Link: Codable {
    var url: String
    var visits: [Date]
    var title: String?
}

class LinkStore: Codable {
    var idGenerator = MonotonicIncreasingID64()
    static var shared = LinkStore()
    lazy var linkManager: LinkManager = { LinkManager() }()

    public private(set) var links = [UInt64: Link]()
    public private(set) var ids = [String: UInt64]()

    init() {
    }

    func loadFromDB() -> Int {
        let loadedLinks = linkManager.loadLinks()
        for link in loadedLinks {
            links[UInt64(bitPattern: link.bid)] = Link(url: link.url, visits: [])
        }
        return loadedLinks.count
    }

    required public init(from decoder: Decoder) throws {
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

    func getIdFor(link: String) -> UInt64? {
        guard let id = ids[link] else {
            return nil
        }

        return id
    }

    func createIdFor(link: String, title: String? = nil) -> UInt64 {
        guard let id = getIdFor(link: link) else {
            let id = MonotonicIncreasingID64.newValue
            ids[link] = id
            links[id] = Link(url: link, visits: [], title: title)
            let linkStruct = LinkStruct(bid: Int64(bitPattern: id), url: link, title: title)
            linkManager.saveLink(linkStruct)
            return id
        }

        return id
    }

    func linkFor(id: UInt64) -> Link? {
        guard let link = links[id] else {
            return nil
        }

        return link
    }

    func visit(link: String, title: String? = nil) {
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

    static func linkFor(_ id: UInt64) -> Link? {
        return shared.linkFor(id: id)
    }

    static func createIdFor(_ link: String, title: String?) -> UInt64 {
        return shared.createIdFor(link: link, title: title)
    }

    static func getIdFor(_ link: String) -> UInt64? {
        return shared.getIdFor(link: link)
    }

    static func isInternalLink(id: UInt64) -> Bool {
        guard let link = linkFor(id) else { return false }
        return isInternal(link: link.url)
    }

    static func isInternal(link: String) -> Bool {
        guard let url = URL(string: link) else { return false }
        return url.scheme == "beam"
    }

    static func loadFrom(_ path: URL) throws {
        let decoder = JSONDecoder()
        shared = try decoder.decode(Self.self, from: Data(contentsOf: path))
    }

    static func saveTo(_ path: URL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(shared)
        try data.write(to: path)
    }
}

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
}

class LinkStore: Codable {
    static var shared = LinkStore()

    public private(set) var links = [UInt64: Link]()
    public private(set) var ids = [String: UInt64]()

    init() {
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        links = try container.decode([UInt64: Link].self, forKey: .links)
        for link in links {
            ids[link.value.url] = link.key
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(links, forKey: .links)
    }

    enum CodingKeys: String, CodingKey {
        case links
    }

    func getIdFor(link: String) -> UInt64? {
        guard let id = ids[link] else {
            return nil
        }

        return id
    }

    func createIdFor(link: String) -> UInt64 {
        guard let id = getIdFor(link: link) else {
            let id = MonotonicIncreasingID64.newValue
            ids[link] = id
            links[id] = Link(url: link, visits: [])
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

    func visit(link: String) {
        let id = createIdFor(link: link)
        guard var linkStruct = linkFor(id: id) else {
            Logger.shared.logError("Unable to fetch Link Structure for link \(link)", category: .search)
            return
        }
        linkStruct.visits.append(Date())
        links[id] = linkStruct
    }

    static func linkFor(_ id: UInt64) -> Link? {
        return shared.linkFor(id: id)
    }

    static func createIdFor(_ link: String) -> UInt64 {
        return shared.createIdFor(link: link)
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
}

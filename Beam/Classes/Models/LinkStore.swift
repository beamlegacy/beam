//
//  LinkStore.swift
//  Beam
//
//  Created by Sebastien Metrot on 17/12/2020.
//

import Foundation

class LinkStore: Codable {
    static var shared = LinkStore()

    public private(set) var links = [UInt64: String]()
    public private(set) var ids = [String: UInt64]()

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
            links[id] = link
            return id
        }

        return id
    }

    func linkFor(id: UInt64) -> String? {
        guard let link = links[id] else {
            return nil
        }

        return link
    }

    static func linkFor(_ id: UInt64) -> String? {
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
        return isInternal(link: link)
    }

    static func isInternal(link: String) -> Bool {
        guard let url = URL(string: link) else { return false }
        return url.scheme == "beam"
    }
}

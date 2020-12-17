//
//  PageRank.swift
//  Beam
//
//  Created by Sebastien Metrot on 24/11/2020.
//

import Foundation
import SwiftSoup

class PageRank: Codable {
    class Page: Codable {
        var id: UInt64 = MonotonicIncreasingID64.newValue
        var inbound = Set<UInt64>()
        var outbound = Set<UInt64>()

        var pageRank: Float = 0

        enum CodingKeys: String, CodingKey {
            case id = "i"
            case inbound = "in"
            case outbound = "out"
        }

        init(_ source: String) {
            id = LinkStore.createIdFor(source)
        }
    }

    var pages = [UInt64: Page]()

    enum CodingKeys: String, CodingKey {
        case pages = "pages"
    }

    var initialValue: Float { 1.0 / ((pages.count > 0) ? Float(pages.count) : 1) }

    func updatePage(source: String, outbounds: [String]) {
        updatePage(source: source, outbounds: outbounds.map({ link -> UInt64 in LinkStore.createIdFor(link)  }))
    }

    func updatePage(source: String, outbounds: [UInt64]) {
        //print("html -> \(html)")
        let page = Page(source)
        let oldPage = pages[page.id]
        page.pageRank = initialValue
        page.inbound = oldPage?.inbound ?? []

        // capture all the links containted in the page:
        for id in outbounds {
//            if let outUrl = URL(string: href, relativeTo: url) {
//                page.outbound.insert(outUrl.absoluteString)
//            } else {
            page.outbound.insert(id)
//            }
        }

        let common = oldPage?.outbound.intersection(page.outbound) ?? []
        let toDelete = oldPage?.outbound.subtracting(common) ?? []
        let toAdd = page.outbound.subtracting(common)

        for linkToUpdate in toDelete {
            pages[linkToUpdate]?.inbound.remove(LinkStore.createIdFor(source))
        }

        for linkToUpdate in toAdd {
            if let page = pages[linkToUpdate] {
                page.inbound.insert(LinkStore.createIdFor(source))
            } else {
                let p = Page(source)
                p.inbound.insert(LinkStore.createIdFor(source))
                pages[linkToUpdate] = p
            }
        }

        page.inbound = oldPage?.inbound ?? []

        pages[page.id] = page
    }

    func updatePage(source: String, contents: String) {
        do {
            //print("html -> \(html)")
            let doc = try SwiftSoup.parseBodyFragment(contents, source)
            let els: Elements = try doc.select("a")

            let page = Page(source)
            page.pageRank = initialValue

            // capture all the links containted in the page:
            let outbounds = try els.array().map { element -> String in
                try element.attr("href")
            }

            updatePage(source: source, outbounds: outbounds)
        } catch Exception.Error(let type, let message) {
            print("PageRank (SwiftSoup parser) \(type): \(message)")
        } catch {
            print("PageRank: (SwiftSoup parser) unkonwn error")
        }
    }

    var dampingFactor = Float(0.85)

    func computePageRanks(iterations: Int = 20) {
        let iv = initialValue
        for pageIterator in pages {
            pageIterator.value.pageRank = iv
        }

        for _ in 0 ..< iterations {
            for pageIterator in pages {
                let page = pageIterator.value

                let score = (page.inbound.map({ inbound -> Float in
                    guard let p = pages[inbound] else { return 0 }
                    let outboundCount = p.outbound.count
                    guard outboundCount > 0 else { return 0 }
                    return p.pageRank / Float(outboundCount)
                }).reduce(0.0, +))
                page.pageRank = (1.0 - dampingFactor) * iv + dampingFactor * score
            }
        }
    }

    func dump() {
        for (key, page) in pages.sorted(by: { (arg0, arg1) -> Bool in
            arg0.value.pageRank > arg1.value.pageRank
        }) {
            Logger.shared.logInfo("Page \(key) - in: \(page.inbound.count) - out: \(page.outbound.count) - pageRank: \(page.pageRank)", category: .document)
        }
    }
}

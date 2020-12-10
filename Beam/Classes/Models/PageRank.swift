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
        var inbound = Set<String>()
        var outbound = Set<String>()

        var pageRank: Float = 0
    }

    var pages = [String: Page]()

    var initialValue: Float { 1.0 / ((pages.count > 0) ? Float(pages.count) : 1) }

    func updatePage(source: String, outbounds: [String]) {
        //print("html -> \(html)")
        let page = Page()
        let oldPage = pages[source]
        page.pageRank = initialValue
        page.inbound = oldPage?.inbound ?? []

        // capture all the links containted in the page:
        for href in outbounds {
//            if let outUrl = URL(string: href, relativeTo: url) {
//                page.outbound.insert(outUrl.absoluteString)
//            } else {
                page.outbound.insert(href)
//            }
        }

        let common = oldPage?.outbound.intersection(page.outbound) ?? []
        let toDelete = oldPage?.outbound.subtracting(common) ?? []
        let toAdd = page.outbound.subtracting(common)

        for linkToUpdate in toDelete {
            pages[linkToUpdate]?.inbound.remove(source)
        }

        for linkToUpdate in toAdd {
            if let page = pages[linkToUpdate] {
                page.inbound.insert(source)
            } else {
                let p = Page()
                p.inbound.insert(source)
                pages[linkToUpdate] = p
            }
        }

        page.inbound = oldPage?.inbound ?? []

        pages[source] = page
    }

    func updatePage(source: String, contents: String) {
        do {
            //print("html -> \(html)")
            let doc = try SwiftSoup.parseBodyFragment(contents, source)
            let els: Elements = try doc.select("a")

            let page = Page()
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

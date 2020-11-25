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

    func updatePage(url: String, contents: String) {
        do {
            //print("html -> \(html)")
            let doc = try SwiftSoup.parseBodyFragment(contents)
            let els: Elements = try doc.select("a")

            let page = Page()

            // capture all the links containted in the page:
            for element: Element in els.array() {
                let href = try element.attr("href")
                page.outbound.insert(href)
            }

            if let oldPage = pages[url] {
                let common = oldPage.outbound.intersection(page.outbound)
                let toDelete = oldPage.outbound.subtracting(common)
                let toAdd = page.outbound.subtracting(common)

                for linkToUpdate in toDelete {
                    pages[linkToUpdate]?.inbound.remove(url)
                }

                for linkToUpdate in toAdd {
                    if let page = pages[linkToUpdate] {
                        page.inbound.insert(url)
                    } else {
                        let p = Page()
                        p.inbound.insert(url)
                        pages[linkToUpdate] = p
                    }
                    pages[linkToUpdate]?.inbound.remove(url)
                }

                page.inbound = oldPage.inbound
            }

            pages[url] = page

        } catch Exception.Error(let type, let message) {
            print("PageRank \(type): \(message)")
        } catch {
            print("PageRank: error")
        }
    }

    var dampingFactor = Float(0.85)

    func computePageRanks(iterations: Int = 20) {
        let initialValue = 1.0 / Float(pages.count)
        for pageIterator in pages {
            pageIterator.value.pageRank = initialValue
        }

        for _ in 0 ..< iterations {
            for pageIterator in pages {
                let page = pageIterator.value

                page.pageRank = (1.0 - dampingFactor)
                    + dampingFactor
                    * (page.inbound.map({ inbound -> Float in
                    guard let p = pages[inbound] else { return 0 }
                    return p.pageRank / Float(p.outbound.count)
                }).reduce(0.0, +))
            }
        }
    }
}

//
//  Readability.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

import Foundation
import WebKit

struct Readability: Codable, Equatable {
    enum Error: Swift.Error {
        case unknown
        case javascript(Swift.Error)
    }

    enum Direction: String, Codable {
        case ltr
        case rtl
    }

    var siteName: String = ""
    var textContent: String = ""
    var dir: Direction = .ltr
    var title: String = ""
    var htmlTitle: String = ""
    var metaTitle: String = ""
    var length: Int = 0
    var content: String = ""
    var excerpt: String = ""
    var byLine: String = ""

    private static var readabilitySource: String?

    static func read(_ webView: WKWebView, _ getResults: @escaping (Result<Readability?, Error>) -> Void) {
        guard let readabilitySource = readabilitySource ?? loadFile(from: "Readability", fileType: "js") else {
            return
        }
        if Self.readabilitySource == nil {
            Self.readabilitySource = readabilitySource
        }

        //let now= BeamDate.now
        webView.evaluateJavaScript(readabilitySource) { (res, err) in
            if let r = res as? [String: Any] {
                var read = Readability()
                read.siteName = str(r["siteName"])
                read.textContent = str(r["textContent"])
                read.dir = str(r["dir"]) == "ltor" ? .ltr : .rtl
                read.title = str(r["title"])
                read.metaTitle = str(r["metaTitle"])
                read.htmlTitle = str(r["htmlTitle"])
                read.length = num(r["length"])
                read.content = str(r["content"])
                read.excerpt = str(r["excerpt"])
                read.byLine = str(r["byLine"])
                //let t0 = now.distance(to: BeamDate.now)
                getResults(.success(read))

                //let t1 = now.distance(to: BeamDate.now) - t0
                //Logger.shared.logDebug("Extraction time: \(t0)s / indexing \(t1)s")
            } else if res is NSNull, let title = webView.title {
                // readability script sometimes doesn't find anything.
                var read = Readability()
                read.title = title
                getResults(.success(read))
            } else if let e = err {
                getResults(.failure(.javascript(e)))
            } else {
                getResults(.failure(.unknown))
            }
        }
    }

    private static func str(_ k: Any?) -> String {
        k as? String ?? ""
    }

    private static func num(_ k: Any?) -> Int {
        k as? Int ?? 0
    }
}

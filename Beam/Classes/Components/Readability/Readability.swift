//
//  Readability.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

// swiftlint:disable file_length
import Foundation
import WebKit

struct Readability: Codable, Equatable {
    enum Direction: String, Codable {
        case ltr
        case rtl
    }

    var siteName: String = ""
    var textContent: String = ""
    var dir: Direction = .ltr
    var title: String = ""
    var length: Int = 0
    var content: String = ""
    var excerpt: String = ""
    var byLine: String = ""

    static func read(_ webView: WKWebView, _ getResults: @escaping (Result<Readability, Error>) -> Void) {
        guard let readabilitySource = loadFile(from: "Readability", fileType: "js") else {
            return
        }

        //let now= BeamDate.now
        webView.evaluateJavaScript(readabilitySource) { (res, err) in
            if let r = res as? [String: Any] {
                var read = Readability()
                read.siteName = str(r["siteName"])
                read.textContent = str(r["textContent"])
                read.dir = str(r["dir"]) == "ltor" ? .ltr : .rtl
                read.title = str(r["title"])
                read.length = num(r["length"])
                read.content = str(r["content"])
                read.excerpt = str(r["excerpt"])
                read.byLine = str(r["byLine"])

                //let t0 = now.distance(to: BeamDate.now)
                getResults(.success(read))

                //let t1 = now.distance(to: BeamDate.now) - t0
                //Logger.shared.logDebug("Extraction time: \(t0)s / indexing \(t1)s")
            } else if let e = err {
                getResults(.failure(e))
            }
        }
    }
}

private func str(_ k: Any?) -> String {
    return k as? String ?? ""
}

private func num(_ k: Any?) -> Int {
    return k as? Int ?? 0
}

// swiftlint:enable file_length

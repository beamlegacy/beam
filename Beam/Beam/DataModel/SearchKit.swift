//
//  SearchKit.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

import Foundation
import CoreServices

class SearchKit {
    var index: SKIndex
    
    init(_ pathUrl: URL) {
        let url = pathUrl as CFURL
        let ndx = SKIndexOpenWithURL(url, "beam" as CFString, true)
        if let ndx = ndx {
            index = ndx.takeRetainedValue()
        } else {
            index = SKIndexCreateWithURL(url, "beam" as CFString, SKIndexType(kSKIndexInverted.rawValue), nil).takeRetainedValue()
        }
    }
    
    deinit {
        SKIndexFlush(index)
    }
    
    func append(url: URL, contents: String) {
        //print("append url to index: \(url)")
        let document = SKDocumentCreateWithURL(url as NSURL).takeRetainedValue()
        SKIndexAddDocumentWithText(index, document, contents.lowercased() as CFString, true)
    }
    
    func search(_ query: String, _ options: SKSearchOptions = UInt32(kSKSearchOptionDefault), countLimit: Int = 10, timeLimit: TimeInterval = 0.05) -> [URL] {
        let options = SKSearchOptions(options)
        let search = SKSearchCreate(index, query.lowercased() as CFString, options).takeRetainedValue()
        
        var documentIDs: [SKDocumentID] = Array(repeating: 0, count: countLimit)
        var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: countLimit)
        var scores: [Float] = Array(repeating: 0, count: countLimit)
        var foundCount = 0

        SKIndexFlush(index)
        let hasMoreResults = SKSearchFindMatches(search, countLimit, &documentIDs, &scores, timeLimit, &foundCount)

        SKIndexCopyDocumentURLsForDocumentIDs(index, foundCount, &documentIDs, &urls)

        let results: [URL] = zip(urls[0 ..< foundCount], scores).compactMap({
            (cfurl, score) -> URL? in
            guard let url = cfurl?.takeRetainedValue() as URL?
                else { return nil }

            print("- \(url): \(score)")
            return url
        })

        print("search \(query) in index:\(results)")

        return results
    }
    
}

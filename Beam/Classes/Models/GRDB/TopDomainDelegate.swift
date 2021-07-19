//
//  TopDomainDelegate.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/07/2021.
//

import Foundation
import BeamCore

class TopDomainDelegate: NSObject, URLSessionDataDelegate {
    let db: TopDomainDatabase
    var buffer = Data()
    var headerSkipped = false
    var serial = DispatchQueue(label: "topDomainCSVParser", qos: .utility)

    private var cancelRequest: Bool = false
    var isCancelled: Bool {
        cancelRequest
    }
    public private(set) var hasStopped: Bool = false

    init(_ db: TopDomainDatabase) {
        self.db = db
    }

    var processedRecordCount = 0

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        let lfValue = Character("\n").asciiValue!
        guard let lastLFIndex = chunk.lastIndex(of: lfValue) else {
            // Wait for next chunk.
            buffer += chunk
            return
        }

        var data = buffer + chunk[..<lastLFIndex]
        let afterLastLFIndex = chunk.index(after: lastLFIndex)
        if afterLastLFIndex < chunk.endIndex {
            buffer = chunk[afterLastLFIndex...]
        } else {
            buffer.removeAll()
        }

        if !headerSkipped {
            guard let firstLFIndex = data.firstIndex(of: lfValue) else { return }

            let afterFirstLFIndex = data.index(after: firstLFIndex)
            guard afterFirstLFIndex < data.endIndex else { return }

            data = data[afterFirstLFIndex...]
            headerSkipped = true
        }

        serial.async {
            guard !self.isCancelled else { return }
            let seq = CSVUnescapingSequence(input: String(decoding: data, as: UTF8.self))
            let parser = CSVParser(input: seq)
            for columns in parser {
                if self.processedRecordCount >= Configuration.topDomainDBMaxSize {
                    dataTask.cancel()
                    self.cancelRequest = true
                    return
                }

                assert(columns.count == 12)
                var record = TopDomainRecord(url: String(columns[2]), globalRank: Int(columns[0])!)
                do {
                    try self.db.insert(topDomain: &record)
                    self.processedRecordCount += 1

                } catch {
                    Logger.shared.logDebug("while inserting top domain record: \(error)", category: .topDomain)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        serial.async {
            self.hasStopped = true
        }
        Logger.shared.logDebug("top domain CSV download completed with \(String(describing: error))", category: .topDomain)
    }
}

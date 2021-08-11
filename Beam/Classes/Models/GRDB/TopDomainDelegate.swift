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
    var totalDiffTime = 0.0

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

        parseData(dataTask, data)
    }

    internal func parseData(_ dataTask: URLSessionDataTask, _ data: Data) {
        /*
         If using `serial.async` this block will continue and `hasStopped` has no meaning as the request will be finished
         before all data has been inserted into the DB.

         Removed async instead.
         */
        guard !self.isCancelled else { return }
        let input = String(decoding: data, as: UTF8.self)

        let seq = CSVUnescapingSequence(input: input)
        let parser = CSVParser(input: seq)
        let localTimer = BeamDate.now

        serial.sync {
            do {
                try self.db.dbWriter.write { db in

                    var localCount = 0

                    for columns in parser {
                        if self.processedRecordCount >= Configuration.topDomainDBMaxSize {
                            dataTask.cancel()
                            self.cancelRequest = true
                            self.totalDiffTime += BeamDate.now.timeIntervalSince(localTimer)

                            Logger.shared.logWarning("Reached \(self.processedRecordCount) total entries. Parsed \(localCount) entries",
                                                     category: .topDomain,
                                                     localTimer: localTimer)
                            return
                        }

                        guard columns.count == 12 else {
                            Logger.shared.logError("CSV doesn't have 12 columns", category: .topDomain)
                            return
                        }

                        var record = TopDomainRecord(url: String(columns[2]), globalRank: Int(columns[0])!)
                        try record.insert(db)
                        self.processedRecordCount += 1
                        localCount += 1
                    }

                    self.totalDiffTime += BeamDate.now.timeIntervalSince(localTimer)

                    Logger.shared.logDebug("Parsed \(localCount) entries",
                                           category: .topDomain,
                                           localTimer: localTimer)
                }
            } catch {
                Logger.shared.logError("while inserting top domain record: \(error.localizedDescription)",
                                       category: .topDomain)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        serial.async {
            self.hasStopped = true
        }

        let diff = String(format: "%.2f", totalDiffTime)

        // -999 are cancelled requests
        if let error = error, ((error as NSError).code != -999 || (error as NSError).domain != "NSURLErrorDomain") {
            Logger.shared.logDebug("CSV download completed with error: \(error.localizedDescription) in \(diff)sec",
                                   category: .topDomain)
            return
        }

        Logger.shared.logDebug("CSV download and parsing completed in \(diff)sec", category: .topDomain)
        Persistence.TopDomains.lastFetchedAt = BeamDate.now
    }
}

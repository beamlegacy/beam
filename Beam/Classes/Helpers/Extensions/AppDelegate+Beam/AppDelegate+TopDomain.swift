import Foundation
import BeamCore

extension AppDelegate {
    func fetchTopDomains(forced: Bool = false) {
        guard Configuration.env != "test" else { return }

        // Will not fetch more than once per week, unless we have no entries
        if !forced,
           let lastFetchedAt = Persistence.TopDomains.lastFetchedAt,
           BeamDate.now.timeIntervalSince(lastFetchedAt) <= (60*60*24*7),
           TopDomainDatabase.shared.count() > 0 {
            let diff = Int(BeamDate.now.timeIntervalSince(lastFetchedAt))
            Logger.shared.logDebug("Last fetch is \(diff)sec old, skip.",
                                   category: .topDomain)
            return
        }

        do {
            try TopDomainDatabase.shared.clear()
        } catch {
            Logger.shared.logWarning("unable to clear top domain DB: \(error)", category: .topDomain)
        }

        let delegate = TopDomainDelegate(TopDomainDatabase.shared)
        let session = URLSession(configuration: .default,
                                 delegate: delegate,
                                 delegateQueue: delegate.queue)
        session.dataTask(with: Configuration.topDomainUrl).resume()
    }
}

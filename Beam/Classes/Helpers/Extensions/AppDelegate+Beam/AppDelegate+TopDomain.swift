import Foundation
import BeamCore

extension AppDelegate {
    func fetchTopDomains(forced: Bool = false) {
        guard Configuration.env != .test else { return }

        // Will not fill database unless we have a new version of the file
        if !forced,
           Persistence.TopDomains.version == Configuration.topDomainsVersion,
           TopDomainDatabase.shared.count() > 0 {
            Logger.shared.logDebug("Last database version is correct", category: .topDomain)
            return
        }

        do {
            try TopDomainDatabase.shared.clear()
        } catch {
            Logger.shared.logWarning("unable to clear top domain DB: \(error)", category: .topDomain)
        }
        TopDomainDatabase.shared.add(Configuration.topDomains)
        Persistence.TopDomains.version = Configuration.topDomainsVersion
    }
}

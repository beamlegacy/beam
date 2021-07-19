import Foundation
import BeamCore

extension AppDelegate {
    func fetchTopDomains() {
        guard Configuration.env != "test" else { return }

        do {
            try TopDomainDatabase.shared.clear()
        } catch {
            Logger.shared.logWarning("unable to clear top domain DB: \(error)", category: .topDomain)
        }

        let session = URLSession(configuration: .ephemeral,
                                 delegate: TopDomainDelegate(TopDomainDatabase.shared),
                                 delegateQueue: nil)
        session.dataTask(with: Configuration.topDomainUrl).resume()
    }
}

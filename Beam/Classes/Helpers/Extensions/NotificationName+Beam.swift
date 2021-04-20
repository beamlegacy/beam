import Foundation

extension Notification.Name {
    static let coredataDestroyed = Notification.Name("coredataDestroyed")
    static let environmentUpdated = Notification.Name("environmentUpdated")
    static let networkUnauthorized = Notification.Name("networkUnauthorized")
    static let networkForbidden = Notification.Name("networkForbidden")
    static let apiDocumentConflict = Notification.Name("apiDocumentConflict")
    static let defaultDatabaseUpdate = Notification.Name("defaultDatabaseUpdate")
}

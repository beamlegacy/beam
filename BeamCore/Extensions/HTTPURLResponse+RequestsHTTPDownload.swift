import Foundation

public extension HTTPURLResponse {

    /// Whether the response suggests it must be downloaded instead of displayed.
    var requestsDownload: Bool {
        let disposition = value(forHTTPHeaderField: "Content-Disposition")
        if let disposition = disposition {
            if disposition.hasPrefix("attachment") { return true }
            if disposition.matches(withRegex: inlineDispositionWithFilenamePattern) { return true }
        }

        let contentType = value(forHTTPHeaderField: "Content-Type")
        if let contentType = contentType {
            if contentType.hasPrefix("application/force-download") { return true }
        }

        return false
    }

    private var inlineDispositionWithFilenamePattern: String {
        "^inline\\s*;\\s*filename="
    }

}

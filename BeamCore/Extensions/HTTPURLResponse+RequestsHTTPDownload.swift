import Foundation

public extension HTTPURLResponse {

    /// Whether the response suggests it must be downloaded instead of displayed.
    var requestsDownload: Bool {
        if let contentType = contentType {
            if contentType.hasPrefix("application/force-download") { return true }
        }

        if let contentDisposition = contentDisposition {
            if contentDisposition.hasPrefix("attachment") { return true }

            // When containing an ambiguous `Content-Disposition: inline; filename=XXX` header, request to download
            // only if the content-type matches the allow list.
            if isAmbiguousInlineContentDisposition && contentTypeRequiresDownload { return true }
        }

        return false
    }

    private var contentType: String? { value(forHTTPHeaderField: "Content-Type") }
    private var contentDisposition: String? { value(forHTTPHeaderField: "Content-Disposition") }

    private var contentTypeRequiresDownload: Bool {
        guard let contentType = contentType else { return false }
        return Self.contentTypesRequiringDownload.contains(contentType)
    }

    /// Matches `Content-Disposition: inline; filename=XXX` response headers.
    private var isAmbiguousInlineContentDisposition: Bool {
        contentDisposition?.matches(withRegex: Self.inlineDispositionWithFilenamePattern) ?? false
    }

    /// An allow list of content-types used when inspecting response headers containing ambiguous
    /// `Content-Disposition: inline; filename=XXX` that must trigger a download.
    private static let contentTypesRequiringDownload = [
        "application/dmg"
    ]

    private static let inlineDispositionWithFilenamePattern: String = "^inline\\s*;\\s*filename="

}

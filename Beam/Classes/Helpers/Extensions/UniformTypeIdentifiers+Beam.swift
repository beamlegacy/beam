import UniformTypeIdentifiers

/// UniformTypeIdentifiers related helpers for Beam, useful to avoid importing the framework everywhere.
enum BeamUniformTypeIdentifiers {

    static let passwordsExportType: UTType = .commaSeparatedText

    static let plainTextType: UTType = .plainText

    private static let supportedSuperTypes: [UTType] = [
        .audiovisualContent,
        .image,
        .text,
        .sourceCode
    ]

    private static let supportedConcreteTypes: [UTType] = [
        .pdf
    ]

    /// Checks whether the file located at the specified URL can be displayed in the web view.
    /// - Parameter url: the `URL` of the local file.
    /// - Returns: `true` if we can correctly display it, `false` otherwise.
    static func supportsNavigation(toLocalFileURL url: URL) -> Bool {
        guard url.isFileURL, let utType = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return supportedConcreteTypes.contains(utType) || supportedSuperTypes.contains(where: { $0.isSupertype(of: utType) })
    }

    /// Checks whether loading this URL within a web view might load additional local resources.
    /// - Parameter url: the `URL` to check.
    /// - Returns: `true` if `URL` is a file URL and if it might load additional local resources, `false` otherwise.
    static func urlMayLoadLocalResources(_ url: URL) -> Bool {
        return url.isFileURL && UTType(filenameExtension: url.pathExtension) == .html
    }

}

extension BeamUniformTypeIdentifiers {
    /// Markdown file extension (there are no provided Markdown UTType yet)
    static let markdownExtension: String = "md"
}

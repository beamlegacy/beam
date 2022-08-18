import UniformTypeIdentifiers

/// UniformTypeIdentifiers related helpers for Beam, useful to avoid importing the framework everywhere.
enum BeamUniformTypeIdentifiers {

    static let passwordsExportType: UTType = .commaSeparatedText

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

}

import Foundation

/// A representation of the download document written to disk during a file download. Can be used to resume a download.
final class BeamDownloadDocument: NSDocument {

    var resumeData: Data?

    /// Download information preserved to disk together with the resume data.
    private(set) var downloadDescription: DownloadDescription?

    init(fileWrapper: FileWrapper) throws {
        super.init()

        try read(from: fileWrapper, ofType: Self.documentTypeName)
    }

    init(downloadDescription: DownloadDescription) {
        self.downloadDescription = downloadDescription

        super.init()
    }

    override init() {
        super.init()
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        let rootWrapper = FileWrapper(directoryWithFileWrappers: [:])

        let encoder = PropertyListEncoder()
        let downloadDescriptionData = try encoder.encode(downloadDescription)
        let downloadDescriptionWrapper = FileWrapper(regularFileWithContents: downloadDescriptionData)
        downloadDescriptionWrapper.preferredFilename = FileContentKey.downloadDescription.rawValue

        if let resumeData = resumeData {
            let resumeDataWrapper = FileWrapper(regularFileWithContents: resumeData)
            resumeDataWrapper.preferredFilename = FileContentKey.resumeData.rawValue
            rootWrapper.addFileWrapper(resumeDataWrapper)
        }

        rootWrapper.addFileWrapper(downloadDescriptionWrapper)
        rootWrapper.preferredFilename = "DownloadRoot"
        return rootWrapper
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard let downloadDescriptionWrapper = fileWrapper.fileWrappers?[FileContentKey.downloadDescription.rawValue],
              let data = downloadDescriptionWrapper.regularFileContents
        else {
            throw Self.Error.incompleteDownloadDocument
        }

        let decoder = PropertyListDecoder()
        downloadDescription = try decoder.decode(DownloadDescription.self, from: data)

        if let resumeDataWrapper = fileWrapper.fileWrappers?[FileContentKey.resumeData.rawValue] {
            resumeData = resumeDataWrapper.regularFileContents
        }
    }

    static let fileExtension = "beamdownload"
    static let documentTypeName = "co.beamapp.download"

    /// Updates the file completion graph visible in Finder.
    static func setFractionCompletedExtendedAttribute(_ fractionCompleted: Double, onFileAt url: URL) {
        let extendedAttributesKey = FileAttributeKey("NSFileExtendedAttributes")

        if var attr = try? FileManager.default.attributesOfItem(atPath: url.path),
           var extAttr = attr[extendedAttributesKey] as? [String: Any] {

            // Add the progress in the file's extended attributes
            let progressData = "\(fractionCompleted)".data(using: .ascii)
            extAttr["com.apple.progress.fractionCompleted"] = progressData

            // Set back the extended attributes in the attributes
            attr[extendedAttributesKey] = extAttr

            // Set the creation date to the January 24th 1984 at 08:00Z for the finder to display the progress
            let magicDate = Date(timeIntervalSince1970: 443779200)
            attr[.creationDate] = magicDate

            // Save the attributes to the file
            try? FileManager.default.setAttributes(attr, ofItemAtPath: url.path)
        }
    }

    enum Error: Swift.Error {
        case incompleteDownloadDocument
    }

    private enum FileContentKey: String {
        case downloadDescription = "DownloadDescription"
        case resumeData = "ResumeData"
    }

}

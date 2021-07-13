//
//  BeamDownloadDocument.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 01/07/2021.
//

import Foundation

enum BeamDownloadDocumentError: Error {
    case incompleteDownloadDocument
}

class BeamDownloadDocument: NSDocument {

    static let downloadDocumentFileExtension = "beamdownload"

    private enum FileContentKeys: String {
        case downloadInfos = "DownloadInfo"
        case resumeData = "DownloadResumeData"
    }

    var downloadData: Data?
    var resumeData: Data?

    init(with download: Download) throws {
        let encoder = PropertyListEncoder()
        downloadData = try encoder.encode(download)
    }

    override init() {
        downloadData = nil
        resumeData = nil
    }

    override var fileType: String? {
        get {
            "co.beamapp.download"
        }

        set {
            super.fileType = newValue
        }
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {

        guard let downloadData = downloadData else { throw BeamDownloadDocumentError.incompleteDownloadDocument }

        let root = FileWrapper(directoryWithFileWrappers: [:])
        let downloadInfo = FileWrapper(regularFileWithContents: downloadData)
        downloadInfo.preferredFilename = FileContentKeys.downloadInfos.rawValue

        if let resumeData = resumeData {
            let resumeData = FileWrapper(regularFileWithContents: resumeData)
            resumeData.preferredFilename = FileContentKeys.resumeData.rawValue
            root.addFileWrapper(resumeData)
        }

        root.addFileWrapper(downloadInfo)
        root.preferredFilename = "DownloadRoot"
        return root
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {

        if let infoWrapper = fileWrapper.fileWrappers?[FileContentKeys.downloadInfos.rawValue],
           let data = infoWrapper.regularFileContents {
            self.downloadData = data
        }

        if let resumeWrapper = fileWrapper.fileWrappers?[FileContentKeys.resumeData.rawValue] {
            self.resumeData = resumeWrapper.regularFileContents
        }
    }

    ///This is not a hack, it's a feature
    static func setProgress(_ progress: Double, onFileAt url: URL) {

        let extendedAttributesKey = FileAttributeKey("NSFileExtendedAttributes")

        if var attr = try? FileManager.default.attributesOfItem(atPath: url.path),
           var extAttr = attr[extendedAttributesKey] as? [String: Any] {

            //Add the progress in the file's extended attributes
            let progressData = "\(progress)".data(using: .ascii)
            extAttr["com.apple.progress.fractionCompleted"] = progressData

            //Set back the extended attributes in the attributes
            attr[extendedAttributesKey] = extAttr

            //Set the creation date to the January 24th 1984 at 08:00Z for the finder to display the progress
            let magicDate = Date(timeIntervalSince1970: 443779200)
            attr[.creationDate] = magicDate

            //Save the attributes to the file
            try? FileManager.default.setAttributes(attr, ofItemAtPath: url.path)
        }
    }
}

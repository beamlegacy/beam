//
//  SandboxEscape.swift
//  Beam
//
//  Created by Frank Lefebvre on 06/09/2021.
//

import Cocoa

enum SandboxEscape {
    final class OpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
        let targetPath: String

        init(targetFile: URL) {
            targetPath = targetFile.path
        }

        func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
            url.path == targetPath
        }
    }

    struct FileGroup {
        var mainFile: URL
        var dependentFiles: [String]
    }

    struct FileCount {
        var currentCount: Int
        var estimatedTotal: Int
    }

    final class TemporaryCopy: URLProvider {
        private let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let wrappedURL: URL

        init?(group: FileGroup) {
            let mainFileName = group.mainFile.lastPathComponent
            wrappedURL = tempDir.appendingPathComponent(mainFileName)
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let sourceDir = group.mainFile.deletingLastPathComponent()
                let fileNames = [mainFileName] + group.dependentFiles
                for fileName in fileNames {
                    try FileManager.default.copyItem(at: sourceDir.appendingPathComponent(fileName), to: tempDir.appendingPathComponent(fileName))
                }
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                return nil
            }
        }

        deinit {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    private enum FileEndorsement {
        case endorsed
        case denied
        case nonexistent
    }

    // Return actual home directory, regardless of whether current app is sandboxed or not
    static func actualHomeDirectory() -> URL {
        let pw = getpwuid(getuid())
        guard let home = pw?.pointee.pw_dir else {
            fatalError("Home directory not available.")
        }
        let homePath = FileManager.default.string(withFileSystemRepresentation: home, length: Int(strlen(home)))
        return URL(fileURLWithPath: homePath)
    }

    static func canOpen(url: URL) throws -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            try? handle.close()
            return true
        } catch {
            let decodedError = error as NSError
            guard decodedError.domain == NSCocoaErrorDomain, decodedError.code == NSFileWriteNoPermissionError else {
                throw error
            }
            return false
        }
    }

    static func message(url: URL, fileCount: FileCount) -> String {
        "Please open \"\(url.lastPathComponent)\" (\(fileCount.currentCount + 1)/\(fileCount.estimatedTotal))"
    }

    /// Allow access to file referenced by URL through Powerbox
    /// - Parameter url: file URL
    /// - Parameter fileCount: currently opened files (updated on success) + estimated total count
    /// - Returns: the URL to be used to access the file contents, or nil if the user cancelled the operation
    /// - Throws: any filesystem error, typically NSFileNoSuchFileError
    static func endorsedURL(for url: URL, fileCount: inout FileCount) throws -> URL? {
        if try canOpen(url: url) {
            fileCount.currentCount += 1
            return url
        }
        let panel = NSOpenPanel()
        let delegate = OpenPanelDelegate(targetFile: url)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = url.deletingLastPathComponent()
        panel.delegate = delegate
        panel.message = message(url: url, fileCount: fileCount)

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            fileCount.currentCount += 1
            return url
        }
        return nil
    }

    private static func endorsementStatus(url: URL, fileCount: inout FileCount) -> FileEndorsement {
        do {
            return try endorsedURL(for: url, fileCount: &fileCount) == nil ? .denied : .endorsed
        } catch {
            let decodedError = error as NSError
            let endorsement: FileEndorsement = decodedError.domain == NSCocoaErrorDomain && decodedError.code == NSFileNoSuchFileError ? .nonexistent : .denied
            if endorsement == .nonexistent {
                fileCount.estimatedTotal -= 1
            }
            return endorsement
        }
    }

    static func endorsedIfExists(url: URL, fileCount: inout FileCount) -> Bool {
        endorsementStatus(url: url, fileCount: &fileCount) != .denied
    }

    static func endorsedGroup(for group: FileGroup, fileCount: inout FileCount) throws -> FileGroup? {
        guard let endorsedMainFile = try endorsedURL(for: group.mainFile, fileCount: &fileCount) else { return nil }
        let parentURL = endorsedMainFile.deletingLastPathComponent()
        var endorsedDependentFiles = [String]()
        for fileName in group.dependentFiles {
            switch endorsementStatus(url: parentURL.appendingPathComponent(fileName), fileCount: &fileCount) {
            case .endorsed:
                endorsedDependentFiles.append(fileName)
            case .denied:
                return nil
            case .nonexistent:
                break
            }
        }
        return FileGroup(mainFile: endorsedMainFile, dependentFiles: endorsedDependentFiles)
    }
}

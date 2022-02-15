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

    /// Allow access to file referenced by URL through Powerbox
    /// - Parameter url: file URL
    /// - Returns: the URL to be used to access the file contents, or nil if the user cancelled the operation
    /// - Throws: any filesystem error, typically NSFileNoSuchFileError
    static func endorsedURL(for url: URL) throws -> URL? {
        if try canOpen(url: url) {
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
        panel.message = "Please open \"\(url.lastPathComponent)\""

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            return url
        }
        return nil
    }

    static func endorsedIfExists(url: URL) -> Bool {
        do {
            return try endorsedURL(for: url) != nil
        } catch {
            let decodedError = error as NSError
            return decodedError.domain == NSCocoaErrorDomain && decodedError.code == NSFileNoSuchFileError
        }
    }
}

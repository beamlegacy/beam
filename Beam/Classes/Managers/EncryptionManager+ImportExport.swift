//
//  EncryptionManager+ImportExport.swift
//  Beam
//
//  Created by Remi Santos on 07/02/2022.
//

import Foundation
import BeamCore
import CryptoKit

extension EncryptionManager {

    static private let defaultFilename = "private.beamkey"

    /// Copies privat ekey to general pasteboard
    func copyKeyToPasteboard() {
        let key = privateKey(for: Persistence.emailOrRaiseError()).asString()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(key, forType: .string)
    }

    /// Saves the current key to a .beamkey file
    ///
    /// - Parameters:
    ///   - atPath: folder path location, if nil a finder panel will be presented for user to select where to save it
    ///   - completion: called with boolean `true` if the file has been succesfully saved
    func saveKeyToFile(atPath: String? = nil, completion: ((Bool) -> Void)?) {

        let key = privateKey(for: Persistence.emailOrRaiseError())
        if let atPath = atPath, let atURL = URL(string: atPath) {
            do {
                try saveToFile(key: key, atURL: atURL)
                completion?(true)
            } catch {
                completion?(false)
                Logger.shared.logError("Couldn't save beamkey file \(error)", category: .disk)
            }
            return
        }
        let fm = FileManager.default
        let panel = NSSavePanel()
        panel.directoryURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.nameFieldStringValue = Self.defaultFilename
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.begin { [unowned self] (result) in
            guard result == .OK, let url = panel.url else {
                panel.close()
                completion?(false)
                return
            }
            do {
                try saveToFile(key: key, atURL: url)
                completion?(true)
            } catch {
                completion?(false)
                Logger.shared.logError("Couldn't save beamkey file \(error)", category: .disk)
            }
        }
    }
    private func saveToFile(key: SymmetricKey, atURL url: URL) throws {
        var path = url
        if path.pathExtension.isEmpty != false {
            path = path.appendingPathComponent(Self.defaultFilename)
        }
        let data = try encodeBeamKeyFile(privateKey(for: Persistence.emailOrRaiseError()))
        try data.write(to: path)
    }

    // import .beamkey file

    /// import key from a .beamkey file
    ///
    /// - Parameters:
    ///   - atPath: if nil, a finder panel will be presented for user to select it
    ///
    func importKeyFromFile(atPath: String? = nil, completion: ((SymmetricKey?) -> Void)?) {

        let workBlock: (URL) -> Void = { [unowned self] url in
            do {
                let key = try self.getFromFile(atURL: url)
                completion?(key)
            } catch {
                Logger.shared.logError(String(describing: error), category: .general)
                completion?(nil)
            }
        }

        if let atPath = atPath, let atURL = URL(string: atPath) {
            workBlock(atURL)
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canDownloadUbiquitousContents = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["beamkey"]
        openPanel.title = "Select a .beamkey file previously exported"
        openPanel.begin { result in
            guard result == .OK, let url = openPanel.url else {
                openPanel.close()
                completion?(nil)
                return
            }
            workBlock(url)
        }
    }

    private func getFromFile(atURL url: URL) throws -> SymmetricKey? {
        let fileManager = FileManager.default
        let path = url.path
        guard fileManager.fileExists(atPath: path) else { return nil }

        let data = try Data(contentsOf: url)
        return try decodeBeamKeyFile(data)
    }

}

// MARK: - File encoding
extension EncryptionManager {

    static private let keyJSONKey = "key"
    private func encodeBeamKeyFile(_ key: SymmetricKey) throws -> Data {
        let dic: [String: String] = [
            Self.keyJSONKey: key.asString()
        ]
        return try JSONSerialization.data(withJSONObject: dic, options: [])
    }

    private func decodeBeamKeyFile(_ data: Data) throws -> SymmetricKey? {
        guard let dic = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
              let keyString = dic[Self.keyJSONKey],
              let key = SymmetricKey(base64EncodedString: keyString) else {
            return nil
        }

        return key
    }
}

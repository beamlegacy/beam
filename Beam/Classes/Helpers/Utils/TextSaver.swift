//
//  TextSaver.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 04/05/2021.
//
import Foundation
import BeamCore

class TextSaver {
    public static var shared = TextSaver()
    var texts = [UUID: Readability]()

    let textsPath: URL
    let encoder: JSONEncoder

    init?() {
        let fileManager = FileManager.default
        guard let documentDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            Logger.shared.logError("Unable to get document direction", category: .web)
            return nil
        }
        textsPath = documentDirectory.appendingPathComponent("texts/")
        do { try fileManager.createDirectory(at: textsPath, withIntermediateDirectories: true) } catch {
            Logger.shared.logError("Unable to create text file dir", category: .web)
            return nil
        }

        encoder = JSONEncoder()
    }

    private func filePath(nodeId: UUID) -> URL {
        return textsPath.appendingPathComponent("\(nodeId).readability")
    }

    public func add(nodeId: UUID, text: Readability) {
        texts[nodeId] = text
    }

    public func save(nodeId: UUID, text: Readability) throws {
        let data = try encoder.encode(text)
        try data.write(to: filePath(nodeId: nodeId), options: .withoutOverwriting)
    }

    public func saveAll() throws {
        for (id, text) in texts {
            try save(nodeId: id, text: text)
        }
    }
}

//
//  OnboardingNoteCreator.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 18/02/2022.
//

import Foundation
import BeamCore

class OnboardingNoteCreator {
    static let shared = OnboardingNoteCreator()

    enum Note: String {
        case yesterday
        case capture
        case howToBeam

        var name: String {
            switch self {
            case .yesterday, .capture:
                return rawValue.prefix(1).capitalized + rawValue.dropFirst()
            case .howToBeam:
                return "How to beam"
            }
        }

        var fileName: String {
            rawValue.prefix(1).capitalized + rawValue.dropFirst()
        }

        var imgNamePrefix: String {
            switch self {
            case .capture: return "cpt"
            case .howToBeam: return "htb"
            case .yesterday: return ""
            }
        }
    }

    func createOnboardingNotes() {
        importNote(Note.capture.fileName)
        importNote(Note.howToBeam.fileName)

        guard let yesterday = Calendar.current.date(byAdding: DateComponents(day: -1), to: BeamDate.now) else { return }
        importNote(Note.yesterday.fileName, forceDate: yesterday)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func importNote(_ fileName: String, forceDate: Date? = nil) {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "json") else { return }
        let url = URL(fileURLWithPath: path)

        guard let data = try? Data(contentsOf: url) else {
            Logger.shared.logError("Unable to import data from \(url)", category: .general)
            return
        }
        let decoder = BeamJSONDecoder()
        guard let note = try? decoder.decode(BeamNote.self, from: data) else {
            Logger.shared.logError("Unable to decode beam note from \(url)", category: .general)
            return
        }

        switch note.type {
        case .journal:
            if let newNote = note.deepCopy(withNewId: true, selectedElements: nil, includeFoldedChildren: true) {
                addImages(in: newNote)
                guard let forceDate = forceDate else {
                    for c in newNote.children {
                        c.parent = AppDelegate.main.data.todaysNote
                    }
                    AppDelegate.main.data.todaysNote.children = newNote.children
                    return
                }

                newNote.creationDate = forceDate
                newNote.updateDate = forceDate
                newNote.type = .journalForDate(forceDate)
                newNote.save()
            }
        case .note:
            addImages(in: note)
            note.creationDate = BeamDate.now
            note.updateDate = BeamDate.now
            note.save()
        }
    }

    private func addImages(in note: BeamNote) {
        var imageCount: Int = 0
        for element in note.children {
            for imageElement in element.imageElements() {
                let filename: String = getImgName(for: note.title, nbr: imageCount)
                let fileType: String = getImgExtension(for: note.title, nbr: imageCount)

                if !filename.isEmpty,
                   let path = Bundle.main.path(forResource: filename, ofType: fileType) {
                    let url = URL(fileURLWithPath: path)

                    if let data = try? Data(contentsOf: url),
                       let image = NSImage(contentsOf: url) {
                        let fileManager = BeamFileDBManager.shared
                        do {
                            let uid = try fileManager.insert(name: url.lastPathComponent, data: data)
                            imageElement.kind = .image(uid, displayInfos: MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width), displayRatio: nil))
                            try fileManager.addReference(fromNote: note.id, element: imageElement.id, to: uid)
                        } catch {
                            Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
                        }
                    }
                    imageCount += 1
                }
            }
        }
    }

    private func getImgName(for noteName: String, nbr: Int) -> String {
        var filename: String = ""
        if noteName == Note.howToBeam.name {
            filename = "\(Note.howToBeam.imgNamePrefix)-\(nbr)"
        }
        if noteName == Note.capture.name {
            filename = "\(Note.capture.imgNamePrefix)-\(nbr)"
        }
        return filename
    }

    private func getImgExtension(for noteName: String, nbr: Int) -> String {
        var fileType: String = "gif"
        if noteName == Note.howToBeam.name {
            if nbr == 2 {
                fileType = "png"
            }
        }
        if noteName == Note.capture.name {
            fileType = "jpg"
        }
        return fileType
    }
}

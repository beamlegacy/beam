//
//  OnboardingNoteCreator.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 18/02/2022.
//

import Foundation
import BeamCore

class OnboardingNoteCreator: BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    enum Note: String {
        case yesterday
        case capture
        case howToBeam

        var name: String {
            switch self {
            case .yesterday, .capture:
                return rawValue.capitalizeFirstChar()
            case .howToBeam:
                return "How to beam"
            }
        }

        var fileName: String {
            rawValue.capitalizeFirstChar()
        }

        var imgNamePrefix: String {
            switch self {
            case .capture: return "cpt"
            case .howToBeam: return "htb"
            case .yesterday: return ""
            }
        }
    }

    func createOnboardingNotes(data: BeamData) {
        importNote(beamData: data, Note.capture.fileName)
        importNote(beamData: data, Note.howToBeam.fileName)

        guard let yesterday = Calendar.current.date(byAdding: DateComponents(day: -1), to: BeamDate.now) else { return }
        importNote(beamData: data, Note.yesterday.fileName, forceDate: yesterday)
    }

    private func importNote(beamData: BeamData, _ fileName: String, forceDate: Date? = nil) {
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
                addImages(in: newNote, beamData: beamData)
                guard let forceDate = forceDate else {
                    for c in newNote.children {
                        c.parent = beamData.todaysNote
                    }
                    beamData.todaysNote.children = newNote.children
                    return
                }

                newNote.title = BeamDate.journalNoteTitle(for: forceDate)
                newNote.creationDate = forceDate
                newNote.updateDate = forceDate
                newNote.type = .journalForDate(forceDate)
                newNote.owner = beamData.currentDatabase
                _ = newNote.save(self)
            }
        case .note, .tabGroup:
            addImages(in: note, beamData: beamData)
            note.creationDate = BeamDate.now
            note.updateDate = BeamDate.now
            note.owner = beamData.currentDatabase
            _ = note.save(self)
        }
    }

    private func addImages(in note: BeamNote, beamData: BeamData) {
        guard let fileManager = beamData.fileDBManager else { return }
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

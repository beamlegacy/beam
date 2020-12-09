import Foundation
import CoreData

struct RoamBullet: Decodable {
    let string: String
    let children: [RoamBullet]?
    let uid: String
    let editTime: Date?
    let editEmail: String?
    let createTime: Date?
    let createEmail: String?

    enum CodingKeys: String, CodingKey {
        case string, children, uid
        case editTime = "edit-time"
        case editEmail = "edit-email"
        case createTime = "create-time"
        case createEmail = "create-email"
    }
}

struct RoamNote: Decodable {
    let title: String
    let children: [RoamBullet]?
    let editTime: Date?
    let editEmail: String?
    let createTime: Date?
    let createEmail: String?

    enum CodingKeys: String, CodingKey {
        case title, children
        case editTime = "edit-time"
        case editEmail = "edit-email"
        case createTime = "create-time"
        case createEmail = "create-email"
    }
}

class RoamImporter {
    lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        return decoder
    }()

    var documentManager = DocumentManager()

    func parseAndCreate(_ context: NSManagedObjectContext, _ filename: String) throws {
        guard let jsonData = NSData(contentsOfFile: filename) as Data? else { return }

        try parseAndCreate(context, jsonData)
    }

    @discardableResult
    func parseAndCreate(_ context: NSManagedObjectContext, _ data: Data) throws -> [RoamNote] {
        let roamNotes = try parseData(data)

        for roamNote in roamNotes {
            let newNote = BeamNote.fetchOrCreate(documentManager, title: roamNote.title)
            newNote.clearChildren()

            if let children = roamNote.children {
                createLocalBullets(context, newNote, children, newNote)
            }

            newNote.creationDate = roamNote.createTime ?? newNote.creationDate
            newNote.updateDate = roamNote.editTime ?? newNote.updateDate
            newNote.save(documentManager: documentManager)
        }

        BeamNote.detectUnlinkedNotes(documentManager)

        return roamNotes
    }

    func parseData(_ data: Data) throws -> [RoamNote] {
        let roamNotes = try decoder.decode([RoamNote].self, from: data)

        return roamNotes
    }

    private func createLocalBullets(_ context: NSManagedObjectContext,
                                    _ note: BeamNote,
                                    _ roamBullets: [RoamBullet],
                                    _ parentBullet: BeamElement) {
        for bullet in roamBullets {
            let newBullet = BeamElement(bullet.string)
            newBullet.creationDate = bullet.createTime ?? newBullet.creationDate
            newBullet.updateDate = bullet.editTime ?? newBullet.updateDate
            parentBullet.addChild(newBullet)
            detectLinkedNotes(context, note: note, bullet: newBullet)

            if let children = bullet.children {
                createLocalBullets(context, note, children, newBullet)
            }
        }
    }

    private func detectLinkedNotes(_ context: NSManagedObjectContext, note: BeamNote, bullet: BeamElement) {
        guard bullet.text.count > 2 else { return }

        for pattern in BMTextFormatter.linkPatterns {
            var regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                // TODO: manage errors
                fatalError("Error")
            }

            let matches = regex.matches(in: bullet.text, options: [], range: NSRange(location: 0, length: bullet.text.utf16.count))

            for match in matches {
                guard let linkRange = Range(match.range(at: 1), in: bullet.text) else { continue }

                let linkTitle = String(bullet.text[linkRange])
                let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
                let reference = NoteReference(noteName: note.title, elementID: bullet.id)
                refnote.addLinkedReference(reference)
                refnote.save(documentManager: documentManager)
            }
        }
    }
}

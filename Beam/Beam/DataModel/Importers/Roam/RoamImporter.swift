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

    func parseAndCreate(_ context: NSManagedObjectContext, _ filename: String) throws {
        guard let jsonData = NSData(contentsOfFile: filename) as Data? else { return }

        try parseAndCreate(context, jsonData)
    }

    @discardableResult
    func parseAndCreate(_ context: NSManagedObjectContext, _ data: Data) throws -> [RoamNote] {
        let roamNotes = try parseData(data)

        for roamNote in roamNotes {
            let newNote = Note.createNote(context, roamNote.title, createdAt: roamNote.createTime ?? roamNote.editTime)
            newNote.updated_at = roamNote.editTime ?? roamNote.createTime ?? Date()

            if let children = roamNote.children {
                createLocalBullets(context, newNote, children)
            }
        }

        Note.detectUnlinkedNotes(context)

        return roamNotes
    }

    func parseData(_ data: Data) throws -> [RoamNote] {
        let roamNotes = try decoder.decode([RoamNote].self, from: data)

        return roamNotes
    }

    private func createLocalBullets(_ context: NSManagedObjectContext,
                                    _ note: Note,
                                    _ roamBullets: [RoamBullet],
                                    _ parentBullet: Bullet? = nil) {
        for bullet in roamBullets {
            let newBullet = note.createBullet(context,
                                              content: bullet.string,
                                              createdAt: bullet.createTime ?? bullet.editTime,
                                              parentBullet: parentBullet)
            newBullet.updated_at = bullet.editTime ?? bullet.createTime ?? Date()
            detectLinkedNotes(context, bullet: newBullet)

            if let children = bullet.children {
                createLocalBullets(context, note, children, newBullet)
            }
        }
    }

    private func detectLinkedNotes(_ context: NSManagedObjectContext, bullet: Bullet) {
        guard bullet.content.count > 2 else { return }

        for pattern in BeamTextFormatter.linkPatterns {
            var regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                // TODO: manage errors
                fatalError("Error")
            }

            let matches = regex.matches(in: bullet.content, options: [], range: NSRange(location: 0, length: bullet.content.utf16.count))

            for match in matches {
                guard let linkRange = Range(match.range(at: 1), in: bullet.content) else { continue }

                let linkTitle = String(bullet.content[linkRange])
                let note = Note.createNote(context, linkTitle)
                note.addToLinkedReferences(bullet)
            }
        }
    }
}

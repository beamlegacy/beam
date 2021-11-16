import Foundation
import CoreData
import BeamCore

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
            let newNote = BeamNote.fetchOrCreate(title: roamNote.title)
            newNote.importedByUser()
            newNote.clearChildren()

            if let children = roamNote.children {
                createLocalBullets(context, newNote, children, newNote)
            }

            newNote.creationDate = roamNote.createTime ?? newNote.creationDate
            newNote.updateDate = roamNote.editTime ?? newNote.updateDate
            newNote.save()
        }

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
            let parser = Parser(inputString: bullet.string)
            let visitor = BeamTextVisitor()
            let newBullet = BeamElement(visitor.visit(parser.parseAST()))
            Logger.shared.logInfo("imported bullet with \(newBullet.text.internalLinks.count) links", category: .document)
            newBullet.creationDate = bullet.createTime ?? newBullet.creationDate
            newBullet.updateDate = bullet.editTime ?? newBullet.updateDate
            parentBullet.addChild(newBullet)

            if let children = bullet.children {
                createLocalBullets(context, note, children, newBullet)
            }
        }
    }
}

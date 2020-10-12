import XCTest
@testable import Beam

class RoamImporterTests: CoreDataTests {
    lazy var fixtureData: Data? = {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "writing_space", ofType: "json")!
        let jsonData = NSData(contentsOfFile: path)
        return jsonData as Data?
    }()

    func testNoteImport() throws {
        let roamImporter = RoamImporter()
        guard let data = fixtureData else {
            fatalError("Can't find roam fixture file")
        }
        let roamNotes = try roamImporter.parseAndCreate(context, data)

        XCTAssertEqual(roamNotes.count, 62)
        XCTAssertEqual(Note.countWithPredicate(context), 65)
        XCTAssertEqual(Bullet.countWithPredicate(context), 291)

        for note in Note.fetchAll(context: context) {
            note.debugNote()
        }
    }
}

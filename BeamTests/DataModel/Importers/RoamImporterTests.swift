import XCTest
@testable import Beam

class RoamImporterTests: CoreDataTests {
    lazy var fixtureData: Data? = {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "writing_space", ofType: "json")!
        let jsonData = NSData(contentsOfFile: path)
        return jsonData as Data?
    }()

    func notestNoteImport() throws {
        let documentManager = DocumentManager()
        let roamImporter = RoamImporter()
        guard let data = fixtureData else {
            fatalError("Can't find roam fixture file")
        }
        let roamNotes = try roamImporter.parseAndCreate(context, data)

        XCTAssertEqual(roamNotes.count, 62)
        XCTAssertEqual(documentManager.count(), 62)

        //swiftlint:disable:next force_try
        let notes = try! documentManager.fetchAll(sortingKey: .title(true))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd' 'HH':'mm':'ss ZZZ"

        XCTAssertEqual(dateFormatter.string(from: notes.first!.created_at), "2020-08-25 11:44:41 +0200")
        XCTAssertEqual(dateFormatter.string(from: notes.last!.created_at), "2020-08-25 11:44:19 +0200")
    }
}

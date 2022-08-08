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
        let roamImporter = RoamImporter()
        guard let data = fixtureData else {
            fatalError("Can't find roam fixture file")
        }

        guard let collection = BeamData.shared.currentDocumentCollection else {
            fatalError("no document collection available")
        }

        let roamNotes = try roamImporter.parseAndCreate(context, data)

        XCTAssertEqual(roamNotes.count, 62)
        XCTAssertEqual(BeamData.shared.currentDatabase?.documentsCount(), 62)

        let notes = try collection.fetch(filters: [], sortingKey: .title(true))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd' 'HH':'mm':'ss ZZZ"

        XCTAssertEqual(dateFormatter.string(from: notes.first!.createdAt), "2020-08-25 11:44:41 +0200")
        XCTAssertEqual(dateFormatter.string(from: notes.last!.createdAt), "2020-08-25 11:44:19 +0200")
    }
}

import XCTest
@testable import Beam

class BeamFileDBManagerTests: XCTestCase {
    var fileDB: BeamFileDBManager!

    override func setUpWithError() throws {
        fileDB = try BeamFileDBManager(path: ":memory:")
        XCTAssertNil(try fileDB.fetchRandom())
        XCTAssertEqual(try fileDB.fileCount(), 0)
    }

    func testAddReferenceAndDeleteAFile() throws {
        let noteId = UUID()
        let element1Id = UUID()
        let element2Id = UUID()
        XCTAssertEqual(try fileDB.fileCount(), 0)
        let fileId = try fileDB.insert(name: "test1", data: "Some test string".asData, type: "text")
        XCTAssertNotEqual(fileId, UUID.null)
        XCTAssertEqual(try fileDB.fileCount(), 1)

        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 0)
        XCTAssertNoThrow(try fileDB.addReference(fromNote: noteId, element: element1Id, to: fileId))
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 1)
        XCTAssertNoThrow(try fileDB.addReference(fromNote: noteId, element: element2Id, to: fileId))
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 2)
        XCTAssertNoThrow(try fileDB.removeReference(fromNote: noteId, element: element1Id))
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 1)
        XCTAssertNoThrow(try fileDB.addReference(fromNote: noteId, element: element2Id, to: fileId))
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 2)
        XCTAssertNoThrow(try fileDB.removeReference(fromNote: noteId, element: nil))
        XCTAssertNoThrow(try fileDB.addReference(fromNote: UUID.null, element: UUID.null, to: fileId))
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 1)
        XCTAssertEqual(try fileDB.fileCount(), 1)
        XCTAssertNoThrow(try fileDB.purgeUnlinkedFiles())
        XCTAssertEqual(try fileDB.fileCount(), 1)
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 1)
        XCTAssertNoThrow(try fileDB.purgeUndo())
        XCTAssertEqual(try fileDB.fileCount(), 1)
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 0)
        XCTAssertNoThrow(try fileDB.purgeUnlinkedFiles())
        XCTAssertEqual(try fileDB.fileCount(), 1) // There is still one file because of the soft delete
        XCTAssertEqual(try fileDB.referenceCount(fileId: fileId), 0)
    }
}

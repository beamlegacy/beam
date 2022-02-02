import Foundation
@testable import BeamCore

/// Creates a empty, uniquely named directory in the system temporary directory.
final class TestDirectory {

    let url: URL

    var path: String { url.path }

    private let fileManager = FileManager.default

    private init(prefix: String) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let dateString = formatter.string(from: BeamDate.now)
        let directoryName = "\(prefix)-\(dateString)"

        url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func delete() throws {
        try fileManager.removeItem(at: url)
    }

    static func makeTestDirectory(prefixed prefix: String) throws -> TestDirectory {
        try TestDirectory(prefix: prefix)
    }

}

import Foundation

/// CodingUserInfoKey constants previously on the deleted BeamObject class.
/// Still referenced by BeamDatabase/BeamDocument Codable conformances.
public enum BeamObject {
    public static let beamObjectCoding = CodingUserInfoKey(rawValue: "beamObjectCoding")!
    public static let beamObjectId = CodingUserInfoKey(rawValue: "beamObjectId")!
}

/// Minimal stub — sync removed. Kept because many model types conform to this.
protocol BeamObjectProtocol: Codable, Hashable {
    static var beamObjectType: BeamObjectObjectType { get }

    var beamObjectId: UUID { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }

    func copy() throws -> Self
}

extension BeamObjectProtocol {
    var description: String {
        "<BeamObjectProtocol: \(beamObjectId) [\(Self.beamObjectType.rawValue)]>"
    }

    var previousChecksum: String? { nil }
    var hasLocalChanges: Bool { false }
    var previousSavedObject: Self? { nil }

    func checksum() throws -> String { "" }
}

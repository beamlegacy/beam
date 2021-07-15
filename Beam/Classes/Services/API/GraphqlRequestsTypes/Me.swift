import Foundation

// swiftlint:disable:next type_name
class Me: Decodable, Errorable {
    var id: String?
    var username: String?
    var email: String?
    var unconfirmedEmail: String?
    var beamObjects: [BeamObject]?
    var documents: [DocumentAPIType]?
    var databases: [DatabaseAPIType]?
    var errors: [UserErrorData]?
    var identities: [IdentityType]?
}

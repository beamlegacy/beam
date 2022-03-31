import Foundation

class UserMe: Decodable, Errorable, APIResponseCodingKeyProtocol {
    static let codingKey = "me"
    var id: String?
    var username: String?
    var email: String?
    var unconfirmedEmail: String?
    var beamObjects: [BeamObject]?
    var paginatedBeamObjects: PaginatedBeamObjects?
    var errors: [UserErrorData]?
    var identities: [IdentityType]?
}

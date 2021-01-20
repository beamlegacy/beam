import Foundation

class Me: Decodable, Errorable {
    static let codingKey = "me"
    var id: String?
    var username: String?
    var email: String?
    var unconfirmedEmail: String?
    var documents: [DocumentAPIType]?
    var errors: [UserErrorData]?
}

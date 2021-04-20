import Foundation

class Me: Decodable, Errorable {
    var id: String?
    var username: String?
    var email: String?
    var unconfirmedEmail: String?
    var documents: [DocumentAPIType]?
    var databases: [DatabaseAPIType]?
    var errors: [UserErrorData]?
}

import Foundation

struct IdentityType: Codable {
    var id: String?
    var provider: String?
    var accessToken: String?
    var email: String?
    var uid: String?
    var createdAt: Date?
    var updatedAt: Date?
}

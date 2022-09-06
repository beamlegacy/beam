import Foundation

struct IdentifiableString: Identifiable {
    let string: String
    var id: String { string }

    init(_ string: String) {
        self.string = string
    }
}

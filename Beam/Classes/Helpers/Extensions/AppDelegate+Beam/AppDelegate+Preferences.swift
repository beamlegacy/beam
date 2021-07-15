import Foundation
import Cocoa
import Preferences

extension Preferences.PaneIdentifier {
    static let general = Self("general")
    static let browser = Self("browser")
    static let cards = Self("cards")
    static let privacy = Self("privacy")
    static let passwords = Self("passwords")
    static let accounts = Self("accounts")
    static let about = Self("about")
    static let advanced = Self("advanced")
}

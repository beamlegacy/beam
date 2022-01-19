import Foundation
import Cocoa
import Preferences

extension Preferences.PaneIdentifier {
    static let general = Self("general")
    static let browser = Self("browser")
    static let notes = Self("notes")
    static let privacy = Self("privacy")
    static let passwords = Self("passwords")
    static let accounts = Self("accounts")
    static let about = Self("about")
    static let beta = Self("beta")
    static let advanced = Self("advanced")
    static let editorDebug = Self("editorDebug")

    static var allBeamPreferences: [Preferences.PaneIdentifier] {
        [.browser, .notes, .privacy, .passwords, .accounts, .about, .beta, .general]
    }

}

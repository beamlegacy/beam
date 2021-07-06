//
//  PasswordManager.swift
//  Beam
//
//  Created by Frank Lefebvre on 16/03/2021.
//

import Foundation
import BeamCore

class PasswordsManager {
    static var passwordsDBPath: String { BeamData.dataFolder(fileName: "passwords.db") }

    var passwordsDB: PasswordsDB

    init() {
        do {
            passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        } catch {
            Logger.shared.logError("Error while creating the Passwords Database \(error)", category: .passwordsDB)
            fatalError()
        }
    }
}

enum DOMInputElementType: String, Codable {
    case text
    case email
    case password
}

struct DOMInputElement: Codable, Equatable, Hashable {
    var type: DOMInputElementType?
    //var id: String
    var beamId: String
    var autocomplete: String?
    var autofocus: String?
    var elementClass: String?
    var name: String?
    var required: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case beamId = "data-beam-id"
        case autocomplete
        case autofocus
        case elementClass = "class"
        case name
        case required
    }
}

enum DOMInputAutocomplete: String, Codable {
    case off = "off"
    case on = "on"
    case email = "email"
    case username = "username"
    case newPassword = "new-password"
    case currentPassword = "current-password"
}

struct DOMRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
}

extension DOMRect {
    var rect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

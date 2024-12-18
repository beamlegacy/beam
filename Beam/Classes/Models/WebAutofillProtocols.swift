//
//  WebAutofillProtocols.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

// MARK: - Passwords

struct PasswordManagerEntry: Hashable {
    var minimizedHost: String
    var username: String
    var neverSaved: Bool
}

struct Credential {
    var username: String
    var password: String
}

extension PasswordManagerEntry {
    init(host: URL, username: String) {
        self.minimizedHost = host.minimizedHost ?? host.urlStringWithoutScheme
        self.username = username
        self.neverSaved = false
    }
}

extension PasswordManagerEntry: Identifiable {
    var id: String {
        "\(minimizedHost) \(username)"
    }
}

struct PasswordManagerHostLookupOptions: OptionSet {
    let rawValue: Int

    static let parentDomains = PasswordManagerHostLookupOptions(rawValue: 1 << 0)
    static let subdomains = PasswordManagerHostLookupOptions(rawValue: 1 << 1)
    static let sharedCredentials = PasswordManagerHostLookupOptions(rawValue: 1 << 2)
    static let genericHost = PasswordManagerHostLookupOptions(rawValue: 1 << 3)

    static let exact: PasswordManagerHostLookupOptions = []
    static let fuzzy: PasswordManagerHostLookupOptions = [.parentDomains, .subdomains, .sharedCredentials, .genericHost]
}

protocol PasswordStore {
    func entries(for hostname: String, options: PasswordManagerHostLookupOptions) throws -> [LocalPasswordRecord]
    func find(_ searchString: String) throws -> [LocalPasswordRecord]
    func fetchAll() throws -> [LocalPasswordRecord]
    func allRecords(_ updatedSince: Date?) throws -> [LocalPasswordRecord]
    func passwordRecord(hostname: String, username: String) throws -> LocalPasswordRecord?
    func save(hostname: String, username: String, encryptedPassword: String, disabledForHost: Bool, privateKeySignature: String, uuid: UUID?) throws -> LocalPasswordRecord
    func save(passwords: [LocalPasswordRecord]) throws
    func update(record: LocalPasswordRecord, hostname: String, username: String, encryptedPassword: String, privateKeySignature: String, uuid: UUID?) throws -> LocalPasswordRecord
    @discardableResult func markUsed(record: LocalPasswordRecord) throws -> LocalPasswordRecord
    @discardableResult func markDeleted(hostname: String, username: String) throws -> LocalPasswordRecord
    @discardableResult func markAllDeleted() throws -> [LocalPasswordRecord]
    @discardableResult func deleteAll() throws -> [LocalPasswordRecord]
    func credentials(for hostname: String, completion: @escaping ([Credential]) -> Void)
}

// MARK: - Personal Information

struct UserInformations: Identifiable {
    var id = UUID()
    var country: Int?
    var organization: String?
    var firstName: String?
    var lastName: String?
    var adresses: String?
    var postalCode: String?
    var city: String?
    var phone: String?
    var email: String?
}

protocol UserInformationsStore {
    func save(userInfo: UserInformations)
    func update(userInfoUUIDToUpdate: UUID, updatedUserInformations: UserInformations)
    func fetchAll() -> [UserInformations]
    func fetchFirst() -> UserInformations
    func delete(id: UUID)
}

// MARK: - Credit Cards

struct CreditCardEntry: Hashable {
    var databaseID: UUID?
    var cardDescription: String
    var cardNumber: String
    var cardHolder: String
    var expirationMonth: Int
    var expirationYear: Int
}

// MARK: - Credit Card Number

extension CreditCardEntry {
    enum CardType {
        case visa
        case masterCard
        case amex
        case discover
        case diners
        case jcb
        case unknown
    }

    enum ExpirationDateStatus {
        case invalid
        case valid
        case expired
    }

    var cardType: CardType {
        switch cardNumber.first {
        case "2", "5":
            return .masterCard
        case "3":
            switch cardNumber.prefix(2) {
            case "30", "36", "38":
                return .diners
            case "34", "37":
                return .amex
            case "35":
                return .jcb
            default:
                return .unknown
            }
        case "4":
            return .visa
        case "6":
            return .discover
        default:
            return .unknown
        }
    }

    var isValidNumber: Bool {
        guard let digits = try? cardNumber.map(String.init).map(Int.init), digits.luhnSum.isMultiple(of: 10) else { return false }
        switch cardType {
        case .visa:
            return cardNumber.count == 13 || cardNumber.count == 16
        case .masterCard, .jcb, .discover:
            return cardNumber.count == 16
        case .amex:
            return cardNumber.count == 15
        case .diners:
            return cardNumber.count == 14
        case .unknown:
            return cardNumber.count >= 13 && cardNumber.count <= 19
        }
    }

    func expirationDateStatus(currentMonth: Int, currentYear: Int) -> ExpirationDateStatus {
        guard expirationMonth >= 1, expirationMonth <= 12, expirationYear >= 2000 else { return .invalid }
        guard expirationYear * 12 + expirationMonth >= currentYear * 12 + currentMonth else { return .expired }
        return .valid
    }
}

private extension Array where Element == Int {
    var luhnSum: Int {
        reversed()
            .enumerated()
            .map { $0.0.isMultiple(of: 2) ? $0.1 : $0.1 * 2 }
            .map { $0 > 9 ? $0 - 9 : $0 }
            .reduce(0, +)
    }
}

// MARK: - Credit Card Formatting

extension CreditCardEntry {
    var typeImageName: String {
        switch cardType {
        case .visa:
            return "autofill-card_visa"
        case .masterCard:
            return "autofill-card_mastercard"
        case .amex:
            return "autofill-card_amex"
        case .discover:
            return "autofill-card_discover"
        case .diners:
            return "autofill-card_generic"
        case .jcb:
            return "autofill-card_jcb"
        case .unknown:
            return "autofill-card_generic"
        }
    }

    var obfuscatedNumber: String {
        let suffixLength = 4
        guard cardNumber.count > suffixLength else { return "" }
        let suffix = cardNumber.suffix(suffixLength)
        let prefix = String(repeating: "x", count: cardNumber.count - suffixLength)
        return formatted(number: prefix + suffix, separator: "-")
    }

    var formattedNumber: String {
        formatted(number: cardNumber)
    }

    var formattedMonth: String {
        String(format: "%02d", expirationMonth)
    }

    var formattedYear: String {
        String(format: "%04d", expirationYear)
    }

    var formattedYearTwoDigits: String {
        String(format: "%02d", expirationYear % 100)
    }

    var formattedDate: String {
        expirationMonth > 0 && expirationYear > 0 ? "\(formattedMonth)/\(formattedYearTwoDigits)" : ""
    }

    private func formatted(number: String, separator: String = " ") -> String {
        let runs: [Int]
        switch (cardType, number.count) {
        case (.visa, 13):
            runs = [4, 3, 3, 3]
        case (.amex, _):
            runs = [4, 6, 5]
        case (.diners, _):
            runs = [4, 6, 4]
        default:
            runs = [4, 4, 4, 4]
        }
        return number.formatted(runs: runs, separator: separator)
    }
}

private extension String {
    func formatted(runs: [Int], separator: String = " ") -> String {
        var remaining = self
        var components = [Substring]()
        for run in runs {
            let component = remaining.prefix(run)
            guard !component.isEmpty else { break }
            remaining.removeFirst(min(run, remaining.count))
            components.append(component)
        }
        if !remaining.isEmpty {
            components.append(Substring(remaining))
        }
        return components.joined(separator: separator)
    }
}

// MARK: -

protocol CreditCardStore {
    func fetchRecord(uuid: UUID) throws -> CreditCardRecord?
    func fetchAll() throws -> [CreditCardRecord]
    func allRecords(updatedSince: Date?) throws -> [CreditCardRecord]
    @discardableResult func addRecord(description: String, cardNumber: String, holder: String, expirationMonth: Int, expirationYear: Int, disabled: Bool) throws -> CreditCardRecord
    @discardableResult func update(record: CreditCardRecord, description: String, cardNumber: String, holder: String, expirationMonth: Int, expirationYear: Int, disabled: Bool) throws -> CreditCardRecord
    @discardableResult func markUsed(record: CreditCardRecord) throws -> CreditCardRecord
    @discardableResult func markDeleted(record: CreditCardRecord) throws -> CreditCardRecord
    @discardableResult func markAllDeleted() throws -> [CreditCardRecord]
    @discardableResult func deleteAll() throws -> [CreditCardRecord]
}

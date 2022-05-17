//
//  CreditCardAutofillBuilder.swift
//  Beam
//
//  Created by Frank Lefebvre on 03/05/2022.
//

import Foundation
import BeamCore

final class CreditCardAutofillBuilder {
    private var creditCardManager: CreditCardAutofillManager
    private var currentHost: String? // actual minimized host (from current page)
    private var autofilledCreditCard: CreditCardEntry?

    private var cardNumber = ""
    private var cardHolder = ""
    private var expirationMonth: Int?
    private var expirationYear: Int?
    private var isDirty = false

    init(creditCardManager: CreditCardAutofillManager = .shared) {
        self.creditCardManager = creditCardManager
    }

    func enterPage(url: URL?) {
        let newHost = url?.minimizedHost
        if newHost != currentHost {
            reset()
            currentHost = newHost
        }
    }

    func autofill(creditCard: CreditCardEntry) {
        autofilledCreditCard = creditCard
    }

    func update(value: String, forRole role: WebInputField.Role) {
        switch role {
        case .cardNumber:
            cardNumber = value
            isDirty = true
        case .cardHolder:
            cardHolder = value
            isDirty = true
        case .cardExpirationDate:
            let components = value.components(separatedBy: "/")
            if components.count == 2, let month = decodedMonth(components[0]), let year = decodedYear(components[1]) {
                expirationMonth = month
                expirationYear = year
                isDirty = true
            } else {
                expirationMonth = nil
                expirationYear = nil
            }
        case .cardExpirationMonth:
            expirationMonth = decodedMonth(value)
            isDirty = true
        case .cardExpirationYear:
            expirationYear = decodedYear(value)
            isDirty = true
        default:
            break
        }
    }

    func unsavedCreditCard() -> CreditCardEntry? {
        Logger.shared.logDebug("CreditCardAutofillBuilder: Checking unsaved status: dirty = \(isDirty)", category: .creditCardAutofill)
        guard isDirty else { return nil }
        let canonicalCardNumber = String(cardNumber.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })
        guard !canonicalCardNumber.isEmpty, !cardHolder.isEmpty, let expirationMonth = expirationMonth, let expirationYear = expirationYear else {
            return nil
        }
        if var updatedCard = autofilledCreditCard {
            var changed = false
            if updatedCard.cardNumber != canonicalCardNumber {
                updatedCard.cardNumber = canonicalCardNumber
                changed = true
            }
            if updatedCard.cardHolder != cardHolder {
                updatedCard.cardHolder = cardHolder
                changed = true
            }
            if updatedCard.expirationMonth != expirationMonth || updatedCard.expirationYear != expirationYear {
                updatedCard.expirationMonth = expirationMonth
                updatedCard.expirationYear = expirationYear
                changed = true
            }
            return changed ? updatedCard : nil
        } else {
            let matchingCards = creditCardManager.find(cardNumber: canonicalCardNumber)
            if matchingCards.contains(where: { $0.expirationMonth == expirationMonth && $0.expirationYear == expirationYear }) {
                return nil // the card is already in the database
            }
        }
        return CreditCardEntry(cardDescription: "", cardNumber: canonicalCardNumber, cardHolder: cardHolder, expirationMonth: expirationMonth, expirationYear: expirationYear)
    }

    func markSaved() {
        Logger.shared.logDebug("CreditCardAutofillBuilder: Saved", category: .creditCardAutofill)
        isDirty = false
    }

    private func reset() {
        autofilledCreditCard = nil
    }

    private func decodedMonth(_ string: String) -> Int? {
        guard let month = Int(string), month >= 1, month <= 12 else { return nil }
        return month
    }

    private func decodedYear(_ string: String) -> Int? {
        guard var year = Int(string), year >= 0 else { return nil }
        if year < 100 {
            year += 2000
        }
        return year
    }
}

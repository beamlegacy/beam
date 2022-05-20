//
//  CreditCardEntryTests.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 03/05/2022.
//

import XCTest
@testable import Beam

// Credit card numbers from https://github.com/drmonkeyninja/test-payment-cards

class CreditCardEntryTests: XCTestCase {
    func testValidAmex() {
        let cardNumber = "370000000000002"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .amex)
        XCTAssertTrue(card.isValidNumber)
        XCTAssertEqual(card.formattedDate, "10/2030")
        XCTAssertEqual(card.formattedNumber, "3700 000000 00002")
    }

    func testInvalidAmex() {
        let cardNumber = "370000000000003" // invalid checksum
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .amex)
        XCTAssertFalse(card.isValidNumber)
        XCTAssertEqual(card.formattedNumber, "3700 000000 00003")
    }

    func testValidDiners() {
        let cardNumber = "38000000000006"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .diners)
        XCTAssertTrue(card.isValidNumber)
        XCTAssertEqual(card.formattedNumber, "3800 000000 0006")
    }

    func testInvalidDiners() {
        let cardNumber = "380000000000069" // too long
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .diners)
        XCTAssertFalse(card.isValidNumber)
    }

    func testValidDiscover() {
        let cardNumber = "6011000000000012"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .discover)
        XCTAssertTrue(card.isValidNumber)
        XCTAssertEqual(card.formattedNumber, "6011 0000 0000 0012")
    }

    func testInvalidDiscover() {
        let cardNumber = "601100000000001" // too short
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .discover)
        XCTAssertFalse(card.isValidNumber)
    }

    func testValidJCB() {
        let cardNumber = "3530111333300000"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .jcb)
        XCTAssertTrue(card.isValidNumber)
        XCTAssertEqual(card.formattedNumber, "3530 1113 3330 0000")
    }

    func testInvalidJCB() {
        let cardNumber = "3500111333300000"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .jcb)
        XCTAssertFalse(card.isValidNumber)
    }

    func testValidMaster() {
        let cardNumber = "5424000000000015"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .masterCard)
        XCTAssertTrue(card.isValidNumber)
    }

    func testInvalidMaster() {
        let cardNumber = "5424000000000020"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .masterCard)
        XCTAssertFalse(card.isValidNumber)
    }

    func testValidVisa() {
        let cardNumber = "4005519200000004"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .visa)
        XCTAssertTrue(card.isValidNumber)
        XCTAssertEqual(card.formattedNumber, "4005 5192 0000 0004")
    }

    func testValidOldVisa() {
        let cardNumber = "4007000000027"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .visa)
        XCTAssertTrue(card.isValidNumber)
        XCTAssertEqual(card.formattedNumber, "4007 000 000 027")
    }

    func testInvalidVisa() {
        let cardNumber = "4005519200000000"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .visa)
        XCTAssertFalse(card.isValidNumber)
    }

    func testValidUnknown() {
        let cardNumber = "1234123412341238"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .unknown)
        XCTAssertTrue(card.isValidNumber)
    }

    func testInvalidUnknown() {
        let cardNumber = "1234123412341234"
        let card = CreditCardEntry(cardDescription: "card", cardNumber: cardNumber, cardHolder: "me", expirationMonth: 10, expirationYear: 2030)
        XCTAssertEqual(card.cardType, .unknown)
        XCTAssertFalse(card.isValidNumber)
    }

    func testValidExpirationDate() {
        let card1 = CreditCardEntry(cardDescription: "card", cardNumber: "0000", cardHolder: "me", expirationMonth: 1, expirationYear: 2023)
        XCTAssertEqual(card1.expirationDateStatus(currentMonth: 5, currentYear: 2022), .valid)
        XCTAssertEqual(card1.expirationDateStatus(currentMonth: 12, currentYear: 2022), .valid)
        XCTAssertEqual(card1.expirationDateStatus(currentMonth: 1, currentYear: 2023), .valid)
        XCTAssertEqual(card1.expirationDateStatus(currentMonth: 2, currentYear: 2023), .expired)
    }

    func testInvalidExpirationDates() {
        let card1 = CreditCardEntry(cardDescription: "card", cardNumber: "0000", cardHolder: "me", expirationMonth: 0, expirationYear: 0)
        XCTAssertEqual(card1.formattedDate, "")
        XCTAssertEqual(card1.expirationDateStatus(currentMonth: 5, currentYear: 2022), .invalid)
        let card2 = CreditCardEntry(cardDescription: "card", cardNumber: "0000", cardHolder: "me", expirationMonth: 12, expirationYear: 24)
        XCTAssertEqual(card2.expirationDateStatus(currentMonth: 5, currentYear: 2022), .invalid)
        let card3 = CreditCardEntry(cardDescription: "card", cardNumber: "0000", cardHolder: "me", expirationMonth: 13, expirationYear: 2024)
        XCTAssertEqual(card3.expirationDateStatus(currentMonth: 5, currentYear: 2022), .invalid)
    }
}

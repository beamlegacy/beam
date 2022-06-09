//
//  BaseCreditCardTest.swift
//  BeamUITests
//
//  Created by Quentin Valero on 24/05/2022.
//

import Foundation
import XCTest

class BaseCreditCardTest: BaseTest {
    let johnCCName = "John's personal Visa"
    let johnCCHiddenNumber = "xxxx-xxxx-xxxx-0123"
    let johnCCNumber = "4701234567890123"
    let johnCCExpDate = "04/2025"
    let johnCCOwnerName = "John Appleseed"
    let janeCCName = "Jane's company Amex"
    let janeCCHiddenNumber = "xxxx-xxxxxx-x8910"
    let janeCCExpDate = "08/2024"
    let janeCCOwnerName = "Jane Appleseed"
    let creditCardNumberLabel = "Credit card number: "
    let creditCardExpDateLabel = "Expiration date: "
    let creditCardExpDateMonthLabel = "Expiration date month: "
    let creditCardExpDateYearLabel = "Expiration date year: "
    let creditCardSecCodeLabel = "Security code: "
    let creditCardOwnerNameLabel = "Name on card: "
    let creditCardOwnerGivenNameLabel = "Given name on card: "
    let creditCardOwnerFamilyNameLabel = "Family name on card: "
    
    //Mock Page
    let creditCardNumberLabelMockPage = "cc-number"
    let creditCardExpDateLabelMockPage  = "cc-exp"
    let creditCardSecCodeLabelMockPage  = "cc-security"
    let creditCardOwnerNameLabelMockPage  = "cc-name"
    
    var creditCardView: CreditCardTestView!

    func verifyAutoFillIsDisplayed(title: String, inView: String = "Payment", password: Bool = false, autocomplete: Bool = true){
        
        step("When I click on \"\(title)\" field") {
            if password {
                mockPage.getPasswordFieldElement(title: title, inView: inView).clickOnExistence()
            } else {
                mockPage.getUsernameFieldElement(title: title, inView: inView).clickOnExistence()
            }
        }

        
        if autocomplete {
            step("Then CC number autofill is displayed") {
                XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCName))
                XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCHiddenNumber))
                XCTAssertTrue(passwordManagerHelper.getOtherCCOptionElement().exists)
            }
        } else {
            step("Then CC number autofill is not displayed") {
                XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCName))
                XCTAssertFalse(passwordManagerHelper.getOtherCCOptionElement().exists)
                XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
            }
        }
        
    }
    
    func verifyDBCCNotes(otherCCAvailable: Bool = false) {
        step("Then Jane and John's cards are displayed") {
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCName))
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCHiddenNumber))
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: janeCCName))
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: janeCCHiddenNumber))
            if otherCCAvailable {
                XCTAssertTrue(passwordManagerHelper.getOtherCCOptionElement().exists)
            } else {
                XCTAssertFalse(passwordManagerHelper.getOtherCCOptionElement().exists)
            }
        }
    }
    
    func verifyCCIsPopulated(number: String, expDate: String, ownerName: String, secCode: String, secCodeIsPassword: Bool = false, inView: String = "Payment") {
        step("Then CC is succesfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: number, inView: inView)), johnCCNumber)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: expDate, inView: inView)), johnCCExpDate)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: ownerName, inView: inView)), johnCCOwnerName)
            if secCodeIsPassword {
                XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: secCode, inView: inView)), emptyString)
            } else {
                XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: secCode, inView: inView)), emptyString)
            }
        }
    }

    func verifyCCAutofillNotDisplayedDropdown(title: String, inView: String = "Payment", autocomplete: Bool = true) {
        step("When I click on \(title) field") {
            mockPage.getDropdownFieldElement(title: title, inView: inView).clickOnExistence()
        }
        
        if autocomplete {
            step("Then CC number autofill is displayed") {
                XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCName))
                XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCHiddenNumber))
                XCTAssertTrue(passwordManagerHelper.getOtherCCOptionElement().exists)
            }
        } else {
            step("Then CC number autofill is not displayed") {
                XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCName))
                XCTAssertFalse(passwordManagerHelper.getOtherCCOptionElement().exists)
            }
        }
        mockPage.typeKeyboardKey(.escape) // Close dropdown
    }
    
}

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
    let creditCardSecCodeLabel = "Security code: "
    let creditCardOwnerNameLabel = "Name on card: "
    
    //Mock Page
    let creditCardNumberLabelMockPage = "cc-number"
    let creditCardExpDateLabelMockPage  = "cc-exp"
    let creditCardSecCodeLabelMockPage  = "cc-security"
    let creditCardOwnerNameLabelMockPage  = "cc-name"
    
    let mockPage = MockHTTPWebPages()
    let helper = PasswordManagerHelper()
    
    var creditCardView: CreditCardTestView!

    func verifyAutoFillIsDisplayed(title: String, inView: String, autocomplete: Bool = true){
        step("When I click on \"\(title)\" field") {
            mockPage.getUsernameFieldElement(title: title, inView: inView).clickOnExistence()
        }
        
        if autocomplete {
            step("Then CC number autofill is displayed") {
                XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: johnCCName))
                XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: johnCCHiddenNumber))
                XCTAssertTrue(helper.getOtherCCOptionElement().exists)
            }
        } else {
            step("Then CC number autofill is not displayed") {
                XCTAssertFalse(helper.doesAutofillPopupExist(autofillText: johnCCName))
                XCTAssertFalse(helper.getOtherCCOptionElement().exists)
            }
        }
        
    }
    
    func verifyDBCCCards(otherCCAvailable: Bool = false) {
        step("Then Jane and John's cards are displayed") {
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: johnCCName))
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: johnCCHiddenNumber))
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: janeCCName))
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: janeCCHiddenNumber))
            if otherCCAvailable {
                XCTAssertTrue(helper.getOtherCCOptionElement().exists)
            } else {
                XCTAssertFalse(helper.getOtherCCOptionElement().exists)
            }
        }
    }
    
    func verifyCCIsPopulated(number: String, expDate: String, ownerName: String, secCode: String, view: String = "Payment") {
        step("Then CC is succesfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: number, inView: view)), johnCCNumber)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: expDate, inView: view)), johnCCExpDate)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: ownerName, inView: view)), johnCCOwnerName)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: secCode, inView: view)), emptyString)
        }
    }
    
}

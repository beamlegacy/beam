//
//  CreditCardSaveTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/05/2022.
//

import Foundation
import XCTest

class CreditCardSaveTests: BaseCreditCardTest {
    
    let alertView = AlertTestView()
    var ccPrefView = AutoFillCCTestView()
    let view = "Payment"
    let fakeCardNumber = "5425233430109903"
    let fakeSecurityCode = "123"
    let expectedCardOwnerName = "Quentin Tester"
    let expectedCardExpDate = "04/23"
    let expectedCardHiddenNumber = "xxxx-xxxx-xxxx-9903"

    let neverSavedCardNumber = "4001000100010009"
    let neverSavedSecurityCode = "000"
    let neverSavedOwnerName = "Somebody"
    let neverSavedExpDate = "08/25"
        
    override func setUp() {
        super.setUp()
        uiMenu.invoke(.startMockHttpServer)
    }
    
    private func fillDataWithoutPwManager(field: String, data: String) {
        step("When I fill \(field) field") {
            mockPage.getUsernameFieldElement(title: field, inView: view).clickOnExistence()
            mockPage.getUsernameFieldElement(title: field, inView: view).clickClearAndType(data)
            mockPage.typeKeyboardKey(.escape) // In case of autocomplete
        }
    }
    
    func testSaveCreditCard(){
        testrailId("C858")
        step("Given I navigate to \(mockPage.getMockPageUrl(.paymentForm))") {
            mockPage.openMockPage(.paymentForm)
        }
        
        fillDataWithoutPwManager(field: creditCardNumberLabel, data: fakeCardNumber)
        fillDataWithoutPwManager(field: creditCardExpDateLabel, data: expectedCardExpDate)
        fillDataWithoutPwManager(field: creditCardSecCodeLabel, data: fakeSecurityCode)
        fillDataWithoutPwManager(field: creditCardOwnerNameLabel, data: expectedCardOwnerName)
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("And I save the CC") {
            alertView.saveCreditCard(waitForAlertToDisappear: true)
        }
        
        step("Then CC is saved in Preferences") {
            uiMenu.invoke(.disablePasswordProtect)
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            creditCardView = PasswordPreferencesTestView().clickEditCreditCardButton()
            let expectedCreditCardRow = RowCreditCardsTestTable(expectedCardOwnerName, expectedCardOwnerName, expectedCardHiddenNumber, expectedCardExpDate)
            let comparisonResult = CreditCardsTestTable().rows[0].isEqualTo(expectedCreditCardRow)
            XCTAssertTrue(comparisonResult.0, comparisonResult.1)
        }
    }
    
    func testDoNotSaveCreditCard(){
        testrailId("C903")
        step("Given I navigate to \(mockPage.getMockPageUrl(.paymentForm))") {
            mockPage.openMockPage(.paymentForm)
        }
        
        fillDataWithoutPwManager(field: creditCardNumberLabel, data: fakeCardNumber)
        fillDataWithoutPwManager(field: creditCardExpDateLabel, data: expectedCardExpDate)
        fillDataWithoutPwManager(field: creditCardSecCodeLabel, data: fakeSecurityCode)
        fillDataWithoutPwManager(field: creditCardOwnerNameLabel, data: expectedCardOwnerName)
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then save alert is displayed") {
            XCTAssertTrue(alertView.notNowButtonExists())
            XCTAssertTrue(alertView.neverSaveCardButtonExists())
        }

        step("When I do not save the CC") {
            alertView.notNowClick()
        }
        
        step("Then CC is not saved in Preferences") {
            uiMenu.invoke(.disablePasswordProtect)
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            PasswordPreferencesTestView().clickEditCreditCardButton()
            XCTAssertEqual(CreditCardsTestTable().getNumberOfVisibleItems(), 0)
        }
    }
    
    func testNeverSavedCreditCard(){
        uiMenu.invoke(.populateCreditCardsDB)

        step("Given I navigate to \(mockPage.getMockPageUrl(.paymentForm))") {
            mockPage.openMockPage(.paymentForm)
        }

        fillDataWithoutPwManager(field: creditCardNumberLabel, data: neverSavedCardNumber)
        fillDataWithoutPwManager(field: creditCardExpDateLabel, data: neverSavedExpDate)
        fillDataWithoutPwManager(field: creditCardSecCodeLabel, data: neverSavedSecurityCode)
        fillDataWithoutPwManager(field: creditCardOwnerNameLabel, data: neverSavedOwnerName)

        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }

        step("Then save alert is not displayed") {
            XCTAssertFalse(alertView.notNowButtonExists())
            XCTAssertFalse(alertView.neverSaveCardButtonExists())
        }
    }

}

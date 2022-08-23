//
//  AdvancedCreditCardTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/05/2022.
//

import Foundation
import XCTest
import SwiftUI

class CreditCardAutocompleteTests: BaseCreditCardTest {
    
    let alertView = AlertTestView()
    var ccPrefView = AutoFillCCTestView()
    var passwordPreferencesView = PasswordPreferencesTestView()
    let view = "Payment"
        
    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populateCreditCardsDB()
        
        step("Given I navigate to \(mockPage.getMockPageUrl(.paymentForm))") {
            mockPage.openMockPage(.paymentForm)
        }
    }
    
    func testValidateAutoFillProposalCC() {
        testrailId("C1085")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, inView: view)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, inView: view)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, inView: view)
    }
    
    func testValidateNoAutoFillCC() {
        testrailId("C1086")
        uiMenu.clearCreditCardsDB()
                
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, inView: view, autocomplete: false)
    }
    
    func testValidateAutoFillDataCC() {

        uiMenu.disablePasswordAndCardsProtection()
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, inView: view)
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerNameLabel, secCode: creditCardSecCodeLabel)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then the results page is populated with credit card data") {
            mockPage.waitForContinueButtonToDisappear(inView: view)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardNumberLabelMockPage), johnCCNumber)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardExpDateLabelMockPage), johnCCExpDate)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardOwnerNameLabelMockPage), johnCCOwnerName)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardSecCodeLabelMockPage), nil)
        }
    }
    
    func testValidateOtherCCMoreThan4() {
        testrailId("C1087")
        // Add two more cards in DB to have 4 cards
        uiMenu.populateCreditCardsDB()
        
        step ("WHEN I deactivate Autofill password setting"){
            uiMenu.disablePasswordAndCardsProtection()
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            if !passwordPreferencesView.getAutofillCCSettingElement().isSettingEnabled() {
                passwordPreferencesView.clickAutofillCC()
            }
            
            XCUIApplication().windows["Passwords"].buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        }
        
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, inView: view)
        
        step("When I click on Other CC") {
            passwordManagerHelper.getOtherCCOptionElement().clickOnExistence()
        }
        
        verifyDBCCNotes(otherCCAvailable: true)
        
        step("When I click on Other CC") {
            ccPrefView = passwordManagerHelper.openCCPreferences()
        }
        
        step("Then CC preferences is displayed") {
            XCTAssertTrue(ccPrefView.isCCPreferencesOpened())
        }
         
        step("And Credit Cards are displayed") {
            var expectedCreditCardRow: RowCreditCardsTestTable
            for index in 0...3 {
                if(index % 2 == 0){
                    expectedCreditCardRow = RowCreditCardsTestTable(johnCCName, johnCCOwnerName, johnCCHiddenNumber, johnCCExpDate)
                } else {
                    expectedCreditCardRow = RowCreditCardsTestTable(janeCCName, janeCCOwnerName, janeCCHiddenNumber, janeCCExpDate)
                }
                let comparisonResult = CreditCardsTestTable().rows[index].isEqualTo(expectedCreditCardRow)
                XCTAssertTrue(comparisonResult.0, comparisonResult.1)
            }
        }
        
        step("When I select first CC") {
            CreditCardsTestTable().selectCreditCardItem(index: 0)
            ccPrefView.clickFill()
        }

        step("Then CC number autofill is not displayed") {
            XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: johnCCName))
            XCTAssertFalse(passwordManagerHelper.getOtherCCOptionElement().exists)
        }
        
        verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerNameLabel, secCode: creditCardSecCodeLabel)
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear(inView: view)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardNumberLabelMockPage), johnCCNumber)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardExpDateLabelMockPage), johnCCExpDate)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardOwnerNameLabelMockPage), johnCCOwnerName)
            XCTAssertEqual(mockPage.getResultValue(label: creditCardSecCodeLabelMockPage), nil)
        }
    }
    
    func testValidateOtherCCLessThan4() {
        testrailId("C1088")
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, inView: view)
        
        step("When I click on Other CC") {
            passwordManagerHelper.getOtherCCOptionElement().clickOnExistence()
        }
        
        verifyDBCCNotes()
    }
    
    func testAutoFillDeactivated() throws {
        try XCTSkipIf(true, "To be fixed in scope of BE-5259")
        testrailId("C638")
        uiMenu.resetUserPreferences()
        step ("WHEN I deactivate Autofill password setting"){
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            if passwordPreferencesView.getAutofillCCSettingElement().isSettingEnabled() {
                passwordPreferencesView.clickAutofillCC()
            }
            
            XCUIApplication().windows["Passwords"].buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        }
        
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, inView: view, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, inView: view, autocomplete: false)
    }
}

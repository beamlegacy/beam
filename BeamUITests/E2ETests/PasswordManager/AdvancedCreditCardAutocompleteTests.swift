//
//  AdvancedCreditCardAutocompleteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 30/05/2022.
//

import Foundation
import XCTest
import SwiftUI

class AdvancedCreditCardAutocompleteTests: BaseCreditCardTest {
    
    let alertView = AlertTestView()
    let uiMenu = UITestsMenuBar()
    var ccPrefView = AutoFillCCTestView()
    var passwordPreferencesView = PasswordPreferencesTestView()
    
    var creditCardsTable: CreditCardsTestTable!
    
    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populateCreditCardsDB()
    }
    
    private func navigateToPayment(page: MockHTTPWebPages.MockPageLink) {
        step("Given I navigate to \(mockPage.getMockPageUrl(page))") {
            mockPage.openMockPage(page)
        }
    }

    func testKiwiAutofill() {
        navigateToPayment(page: .paymentKiwiForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testOplataAutofill() {
        navigateToPayment(page: .paymentOplataForm)
        verifyAutoFillIsDisplayed(title: "Mobile Number: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password: true, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testBookingAutofill() {
        navigateToPayment(page: .paymentBookingForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testSportDecouverteAutofill() {
        navigateToPayment(page: .paymentSportDecouverteForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testAmazonAutofill() {
        navigateToPayment(page: .paymentAmazonForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password: true, autocomplete: false)
        // Selecting any of these fields triggers the autofill menu to be displayed below the field menu.
        // TODO: enable the lines below when BE-4304 is fixed.
//        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
//        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testEbayAutofill() {
        navigateToPayment(page: .paymentEbayForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testWalmartAutofill() {
        navigateToPayment(page: .paymentWalmartForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        // TODO: enable the lines below when BE-4304 is fixed.
//        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
//        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testEtsySearsAutofill() {
        navigateToPayment(page: .paymentEtsySearsForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testWishAutofill() {
        navigateToPayment(page: .paymentWishForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testBestBuyAutofill() {
        navigateToPayment(page: .paymentBestBuyForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testTargetAutofill() {
        navigateToPayment(page: .paymentTargetForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testKohlsAirBnbAutofill() {
        navigateToPayment(page: .paymentKohlsAirbnbForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHotelsAutofill() {
        navigateToPayment(page: .paymentHotelsForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testExpediaAutofill() {
        navigateToPayment(page: .paymentExpediaForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testPricelineAutofill() {
        navigateToPayment(page: .paymentPricelineForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHotwireAutofill() {
        navigateToPayment(page: .paymentHotwireForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testKayakAutofill() {
        navigateToPayment(page: .paymentKayakForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testAgodaAutofill() {
        navigateToPayment(page: .paymentAgodaForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password:true, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerNameLabel, secCode: creditCardSecCodeLabel, secCodeIsPassword: true)
        }
    }
    
    func testNetflixAutofill() {
        navigateToPayment(page: .paymentNetflixShortForm) // must be dedicated domain name to apply rule for netflix.com
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerFamilyNameLabel, secCode: creditCardSecCodeLabel)
        }
    }
    
    func testDisneyAutofill() {
        navigateToPayment(page: .paymentDisneyForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHboMaxAutofill() {
        navigateToPayment(page: .paymentHboMaxForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testYoutubeAutofill() {
        navigateToPayment(page: .paymentYoutubeForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testSpotifyAutofill() {
        navigateToPayment(page: .paymentSpotifyForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testAppleAutofill() {
        navigateToPayment(page: .paymentAppleForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerFamilyNameLabel, secCode: creditCardSecCodeLabel)
        }
    }
    
    func testUberAutofill() {
        navigateToPayment(page: .paymentUberForm)
        verifyAutoFillIsDisplayed(title: "Nickname: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testDoordashAutofill() {
        navigateToPayment(page: .paymentDoordashForm)
        verifyAutoFillIsDisplayed(title: "ZIP Code: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
}

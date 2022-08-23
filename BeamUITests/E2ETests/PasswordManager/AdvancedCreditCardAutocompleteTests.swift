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
    var ccPrefView = AutoFillCCTestView()
    var passwordPreferencesView = PasswordPreferencesTestView()
        
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
        testrailId("C876")
        navigateToPayment(page: .paymentKiwiForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testOplataAutofill() {
        testrailId("C877")
        navigateToPayment(page: .paymentOplataForm)
        verifyAutoFillIsDisplayed(title: "Mobile Number: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password: true, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testBookingAutofill() {
        testrailId("C878")
        navigateToPayment(page: .paymentBookingShortForm) // must be dedicated domain name to apply rule for booking.com
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testSportDecouverteAutofill() {
        testrailId("C879")
        navigateToPayment(page: .paymentSportDecouverteForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testAmazonAutofill() {
        testrailId("C880")
        navigateToPayment(page: .paymentAmazonForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password: true, autocomplete: false)
        // Selecting any of these fields triggers the autofill menu to be displayed below the field menu.
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testEbayAutofill() {
        testrailId("C881")
        navigateToPayment(page: .paymentEbayForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testWalmartAutofill() {
        testrailId("C882")
        navigateToPayment(page: .paymentWalmartForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testEtsySearsAutofill() {
        testrailId("C883")
        navigateToPayment(page: .paymentEtsySearsForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testWishAutofill() {
        testrailId("C884")
        navigateToPayment(page: .paymentWishForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testBestBuyAutofill() {
        testrailId("C885")
        navigateToPayment(page: .paymentBestBuyForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testTargetAutofill() {
        testrailId("C886")
        navigateToPayment(page: .paymentTargetForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testKohlsAirBnbAutofill() {
        testrailId("C887")
        navigateToPayment(page: .paymentKohlsAirbnbForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHotelsAutofill() {
        testrailId("C888")
        navigateToPayment(page: .paymentHotelsForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testExpediaAutofill() {
        testrailId("C889")
        navigateToPayment(page: .paymentExpediaForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testPricelineAutofill() {
        testrailId("C890")
        navigateToPayment(page: .paymentPricelineForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHotwireAutofill() {
        testrailId("C891")
        navigateToPayment(page: .paymentHotwireForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testKayakAutofill() {
        testrailId("C892")
        navigateToPayment(page: .paymentKayakForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testAgodaAutofill() {
        testrailId("C893")
        navigateToPayment(page: .paymentAgodaForm)
        uiMenu.disablePasswordAndCardsProtection()
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password:true, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerNameLabel, secCode: creditCardSecCodeLabel, secCodeIsPassword: true)
        }
    }
    
    func testNetflixAutofill() {
        testrailId("C894")
        navigateToPayment(page: .paymentNetflixShortForm) // must be dedicated domain name to apply rule for netflix.com
        uiMenu.disablePasswordAndCardsProtection()
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerFamilyNameLabel, secCode: creditCardSecCodeLabel)
        }
    }
    
    func testDisneyAutofill() {
        testrailId("C895")
        navigateToPayment(page: .paymentDisneyForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHboMaxAutofill() {
        testrailId("C896")
        navigateToPayment(page: .paymentHboMaxForm)
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testYoutubeAutofill() {
        testrailId("C897")
        navigateToPayment(page: .paymentYoutubeForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testSpotifyAutofill() {
        testrailId("C898")
        navigateToPayment(page: .paymentSpotifyForm)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testAppleAutofill() {
        testrailId("C899")
        navigateToPayment(page: .paymentAppleForm)
        uiMenu.disablePasswordAndCardsProtection()
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerFamilyNameLabel, secCode: creditCardSecCodeLabel)
        }
    }
    
    func testUberAutofill() {
        testrailId("C900")
        navigateToPayment(page: .paymentUberForm)
        verifyAutoFillIsDisplayed(title: "Nickname: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testDoordashAutofill() {
        testrailId("C901")
        navigateToPayment(page: .paymentDoordashForm)
        verifyAutoFillIsDisplayed(title: "ZIP Code: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
}

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
    
    private func navigateToPayment(page: String){
        step("Given I navigate to \(page)") {
            OmniBoxTestView().searchInOmniBox(mockBaseUrl + page, true)
        }
    }
    
    func testKiwiAutofill() {
        navigateToPayment(page: "payment-kiwi")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testOplataAutofill() {
        navigateToPayment(page: "payment-oplata")
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password: true, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testBookingAutofill() {
        navigateToPayment(page: "payment-booking")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testSportDecouverteAutofill() {
        navigateToPayment(page: "payment-sport-decouverte")
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func skipAmazonAutofill() { // Activate once BE-4264 is fixed
        navigateToPayment(page: "payment-amazon")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password: true, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testEbayAutofill() {
        navigateToPayment(page: "payment-ebay")
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testWalmartAutofill() {
        navigateToPayment(page: "payment-walmart")
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testEtsySearsAutofill() {
        navigateToPayment(page: "payment-etsy-sears")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testWishAutofill() {
        navigateToPayment(page: "payment-wish")
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testBestBuyAutofill() {
        navigateToPayment(page: "payment-bestbuy")
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testTargetAutofill() {
        navigateToPayment(page: "payment-target")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testKohlsAirBnbAutofill() {
        navigateToPayment(page: "payment-kohls-airbnb")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHotelsAutofill() {
        navigateToPayment(page: "payment-hotels")
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testExpediaAutofill() {
        navigateToPayment(page: "payment-expedia")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testPricelineAutofill() {
        navigateToPayment(page: "payment-priceline")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHotwireAutofill() {
        navigateToPayment(page: "payment-hotwire")
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testKayakAutofill() {
        navigateToPayment(page: "payment-kayak")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateYearLabel, autocomplete: false)
        verifyCCAutofillNotDisplayedDropdown(title: creditCardExpDateMonthLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func skipAgodaAutofill() { // Activate once BE-4273 is fixed
        navigateToPayment(page: "payment-agoda")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, password:true, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerNameLabel, secCode: creditCardSecCodeLabel)
        }
    }
    
    func skipNetflixAutofill() { // Activate once BE-4277 is fixed
        navigateToPayment(page: "payment-netflix")
        verifyAutoFillIsDisplayed(title: creditCardOwnerFamilyNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardOwnerGivenNameLabel, autocomplete: false) // in this case, autofill only proposed for Family name
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: johnCCName)
        }
        
        step("Then CC is succesfully populated") {
            verifyCCIsPopulated(number: creditCardNumberLabel, expDate: creditCardExpDateLabel, ownerName: creditCardOwnerNameLabel, secCode: creditCardSecCodeLabel)
        }
    }
    
    func testDisneyAutofill() {
        navigateToPayment(page: "payment-disney")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel, autocomplete: false)
    }
    
    func testHboMaxAutofill() {
        navigateToPayment(page: "payment-hbomax")
        verifyAutoFillIsDisplayed(title: creditCardOwnerNameLabel)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testYoutubeAutofill() {
        navigateToPayment(page: "payment-youtube")
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateYearLabel)
        verifyAutoFillIsDisplayed(title: creditCardExpDateMonthLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testSpotifyAutofill() {
        navigateToPayment(page: "payment-spotify")
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func skipAppleAutofill() { // Activate once BE-4278 is fixed
        navigateToPayment(page: "payment-apple")
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
        navigateToPayment(page: "payment-uber")
        verifyAutoFillIsDisplayed(title: "Nickname: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
    
    func testDoordashAutofill() {
        navigateToPayment(page: "payment-doordash")
        verifyAutoFillIsDisplayed(title: "ZIP Code: ", autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardSecCodeLabel, autocomplete: false)
        verifyAutoFillIsDisplayed(title: creditCardExpDateLabel)
        verifyAutoFillIsDisplayed(title: creditCardNumberLabel)
    }
}

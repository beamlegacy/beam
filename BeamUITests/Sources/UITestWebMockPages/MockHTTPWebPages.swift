//
//  MockHTTPWebPages.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class MockHTTPWebPages: BaseView {
    
    func getPasswordFieldElement(_ isSignUp: Bool = true) -> XCUIElement {
        let viewAccessibility = isSignUp ? "Sign Up" : "Sign In"
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:"Password: ").children(matching: .secureTextField).element
    }
    
    func getPasswordFieldElement(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .secureTextField).element
    }
    
    func getPasswordElementWithValue(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .textField).element
    }

    func getConfirmPasswordFieldElement() -> XCUIElement {
        return app.windows.webViews["Sign Up"].groups.containing(.staticText, identifier:"Confirm Password: ").children(matching: .secureTextField).element
    }

    func getUsernameFieldElement(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .textField).element
    }

    func getLinkElement(_ title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].links.containing(.staticText, identifier: title).element
    }

    func getContinueButtonElement(inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].buttons["Continue"]
    }
    
    func waitForContinueButtonToDisappear(inView viewAccessibility: String = "Sign In") {
        waitForDoesntExist(app.windows.webViews[viewAccessibility].buttons["Continue"])
    }
    
    func getNextButtonElement(inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].staticTexts["Next"]
    }

    func getDropdownFieldElement(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .popUpButton).element
    }
    
    func setDropdownFieldElement(value: String, inView viewAccessibility: String = "Sign In") -> Void {
        app.windows.menuItems[value].clickOnExistence()
    }
    
    func getResultValue(label: String) -> String? {
        let staticTexts = app.windows.webViews["Mock Form Server"].groups.containing(.staticText, identifier: label).children(matching: .staticText)
        guard staticTexts.count > 2 else { return nil }
        let element = staticTexts.element(boundBy: 2)
        return element.getStringValue()
    }
    
    enum MockPageLink: String, CaseIterable {
        case mainView = "http://localhost:8080/"
        case mockBaseUrl = "http://form.lvh.me:8080/"
        
        case ambiguousShortForm = "http://ambiguous.form.lvh.me:8080/"
        case signupShortForm = "http://signup.form.lvh.me:8080/"
        case signinShortForm = "http://signin.form.lvh.me:8080/"
        case paymentNetflixShortForm = "http://payment-netflix.form.lvh.me:8080/"
        
        case signupForm = "http://form.lvh.me:8080/signup"
        case signinForm = "http://form.lvh.me:8080/signin"
        case signin1Form = "http://form.lvh.me:8080/signinpage1"
        case signin2Form = "http://form.lvh.me:8080/signinpage2"
        case signin3Form = "http://form.lvh.me:8080/signinpage3"
        case signin4Form = "http://form.lvh.me:8080/signinpage4"
        case signin5Form = "http://form.lvh.me:8080/signinpage5"
        case signin61Form = "http://form.lvh.me:8080/signinpage6-1"
        case signin71Form = "http://form.lvh.me:8080/signinpage7-1"
        case signin8Form = "http://form.lvh.me:8080/signinpage8"
        case signin91Form = "http://form.lvh.me:8080/signinpage9-1"
        case signin92Form = "http://form.lvh.me:8080/signinpage9-2"
        case signinstep2Form = "http://form.lvh.me:8080/signinstep2"
        case signinebayForm = "http://form.lvh.me:8080/signinebay"
        case signup1Form = "http://form.lvh.me:8080/signuppage1"
        case signup2Form = "http://form.lvh.me:8080/signuppage2"
        case signup3Form = "http://form.lvh.me:8080/signuppage3"
        case signup4Form = "http://form.lvh.me:8080/signuppage4"
        case signup51Form = "http://form.lvh.me:8080/signuppage5-1"
        case signup6Form = "http://form.lvh.me:8080/signuppage6"
        
        case paymentForm = "http://form.lvh.me:8080/payment"
        case paymentKiwiForm = "http://form.lvh.me:8080/payment-kiwi"
        case paymentOplataForm = "http://form.lvh.me:8080/payment-oplata"
        case paymentBookingForm = "http://form.lvh.me:8080/payment-booking"
        case paymentSportDecouverteForm = "http://form.lvh.me:8080/payment-sport-decouverte"
        case paymentAmazonForm = "http://form.lvh.me:8080/payment-amazon"
        case paymentEbayForm = "http://form.lvh.me:8080/payment-ebay"
        case paymentWalmartForm = "http://form.lvh.me:8080/payment-walmart"
        case paymentEtsySearsForm = "http://form.lvh.me:8080/payment-etsy-sears"
        case paymentWishForm = "http://form.lvh.me:8080/payment-wish"
        case paymentBestBuyForm = "http://form.lvh.me:8080/payment-bestbuy"
        case paymentTargetForm = "http://form.lvh.me:8080/payment-target"
        case paymentKohlsAirbnbForm = "http://form.lvh.me:8080/payment-kohls-airbnb"
        case paymentHotelsForm = "http://form.lvh.me:8080/payment-hotels"
        case paymentExpediaForm = "http://form.lvh.me:8080/payment-expedia"
        case paymentPricelineForm = "http://form.lvh.me:8080/payment-priceline"
        case paymentHotwireForm = "http://form.lvh.me:8080/payment-hotwire"
        case paymentKayakForm = "http://form.lvh.me:8080/payment-kayak"
        case paymentAgodaForm = "http://form.lvh.me:8080/payment-agoda"
        case paymentNetflixForm = "http://form.lvh.me:8080/payment-netflix"
        case paymentDisneyForm = "http://form.lvh.me:8080/payment-disney"
        case paymentHboMaxForm = "http://form.lvh.me:8080/payment-hbomax"
        case paymentYoutubeForm = "http://form.lvh.me:8080/payment-youtube"
        case paymentSpotifyForm = "http://form.lvh.me:8080/payment-spotify"
        case paymentAppleForm = "http://form.lvh.me:8080/payment-apple"
        case paymentUberForm = "http://form.lvh.me:8080/payment-uber"
        case paymentDoordashForm = "http://form.lvh.me:8080/payment-doordash"

        case visibilityForm = "http://form.lvh.me:8080/visibility"
        
        case socialMediaAdBlock = "http://social-media-adblock.test.adblock.lvh.me:8080/"
        case insideAdBlock = "http://inside-adblock.test.adblock.lvh.me:8080/"
        case fullSiteAdBlock = "http://a-stat.test.adblock.lvh.me:8080/"
        case cookieBannerAdBlock = "http://annoyances-adblock.test.adblock.lvh.me:8080/"
        case popupBannerAdBlock = "http://annoyances2-adblock.test.adblock.lvh.me:8080/"
        case adsBannerAdBlock = "http://annoyances3-adblock.test.adblock.lvh.me:8080/"
        
        case newWindowBrowser = "http://windowopen.browser.lvh.me:8080/"
        
        case testPdfFile = "http://www.lvh.me:8080/static/test.pdf"

    }
    
    @discardableResult
    func openMockPage(_ pageLink: MockPageLink) -> WebTestView {
        let omniboxView = OmniBoxTestView()
        omniboxView.searchInOmniBox(pageLink.rawValue, true)
        return WebTestView()
    }
    
    func getMockPageUrl(_ pageLink: MockPageLink) -> String {
        return pageLink.rawValue
    }
    
}

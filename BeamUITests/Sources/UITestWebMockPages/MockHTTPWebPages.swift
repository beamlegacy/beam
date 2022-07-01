//
//  MockHTTPWebPages.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest
import BeamCore

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
    
    enum MockPageLink: CaseIterable {
        case mainView
        case mockBaseUrl

        case ambiguousShortForm
        case signupShortForm
        case signinShortForm
        case paymentNetflixShortForm

        case signupForm
        case signinForm
        case signin1Form
        case signin2Form
        case signin3Form
        case signin4Form
        case signin5Form
        case signin61Form
        case signin71Form
        case signin8Form
        case signin91Form
        case signin92Form
        case signinstep2Form
        case signinebayForm
        case signup1Form
        case signup2Form
        case signup3Form
        case signup4Form
        case signup51Form
        case signup6Form

        case paymentForm
        case paymentKiwiForm
        case paymentOplataForm
        case paymentBookingForm
        case paymentSportDecouverteForm
        case paymentAmazonForm
        case paymentEbayForm
        case paymentWalmartForm
        case paymentEtsySearsForm
        case paymentWishForm
        case paymentBestBuyForm
        case paymentTargetForm
        case paymentKohlsAirbnbForm
        case paymentHotelsForm
        case paymentExpediaForm
        case paymentPricelineForm
        case paymentHotwireForm
        case paymentKayakForm
        case paymentAgodaForm
        case paymentNetflixForm
        case paymentDisneyForm
        case paymentHboMaxForm
        case paymentYoutubeForm
        case paymentSpotifyForm
        case paymentAppleForm
        case paymentUberForm
        case paymentDoordashForm

        case visibilityForm

        case socialMediaAdBlock
        case insideAdBlock
        case fullSiteAdBlock
        case cookieBannerAdBlock
        case popupBannerAdBlock
        case adsBannerAdBlock

        case newWindowBrowser

        case testPdfFile

        var rawValue: String {
            let port = EnvironmentVariables.MockHttpServer.port
            switch self {
            case .mainView: return "http://localhost:\(port)/"
            case .mockBaseUrl: return "http://form.lvh.me:\(port)/"

            case .ambiguousShortForm: return "http://ambiguous.form.lvh.me:\(port)/"
            case .signupShortForm: return "http://signup.form.lvh.me:\(port)/"
            case .signinShortForm: return "http://signin.form.lvh.me:\(port)/"
            case .paymentNetflixShortForm: return "http://payment-netflix.form.lvh.me:\(port)/"

            case .signupForm: return "http://form.lvh.me:\(port)/signup"
            case .signinForm: return "http://form.lvh.me:\(port)/signin"
            case .signin1Form: return "http://form.lvh.me:\(port)/signinpage1"
            case .signin2Form: return "http://form.lvh.me:\(port)/signinpage2"
            case .signin3Form: return "http://form.lvh.me:\(port)/signinpage3"
            case .signin4Form: return "http://form.lvh.me:\(port)/signinpage4"
            case .signin5Form: return "http://form.lvh.me:\(port)/signinpage5"
            case .signin61Form: return "http://form.lvh.me:\(port)/signinpage6-1"
            case .signin71Form: return "http://form.lvh.me:\(port)/signinpage7-1"
            case .signin8Form: return "http://form.lvh.me:\(port)/signinpage8"
            case .signin91Form: return "http://form.lvh.me:\(port)/signinpage9-1"
            case .signin92Form: return "http://form.lvh.me:\(port)/signinpage9-2"
            case .signinstep2Form: return "http://form.lvh.me:\(port)/signinstep2"
            case .signinebayForm: return "http://form.lvh.me:\(port)/signinebay"
            case .signup1Form: return "http://form.lvh.me:\(port)/signuppage1"
            case .signup2Form: return "http://form.lvh.me:\(port)/signuppage2"
            case .signup3Form: return "http://form.lvh.me:\(port)/signuppage3"
            case .signup4Form: return "http://form.lvh.me:\(port)/signuppage4"
            case .signup51Form: return "http://form.lvh.me:\(port)/signuppage5-1"
            case .signup6Form: return "http://form.lvh.me:\(port)/signuppage6"

            case .paymentForm: return "http://form.lvh.me:\(port)/payment"
            case .paymentKiwiForm: return "http://form.lvh.me:\(port)/payment-kiwi"
            case .paymentOplataForm: return "http://form.lvh.me:\(port)/payment-oplata"
            case .paymentBookingForm: return "http://form.lvh.me:\(port)/payment-booking"
            case .paymentSportDecouverteForm: return "http://form.lvh.me:\(port)/payment-sport-decouverte"
            case .paymentAmazonForm: return "http://form.lvh.me:\(port)/payment-amazon"
            case .paymentEbayForm: return "http://form.lvh.me:\(port)/payment-ebay"
            case .paymentWalmartForm: return "http://form.lvh.me:\(port)/payment-walmart"
            case .paymentEtsySearsForm: return "http://form.lvh.me:\(port)/payment-etsy-sears"
            case .paymentWishForm: return "http://form.lvh.me:\(port)/payment-wish"
            case .paymentBestBuyForm: return "http://form.lvh.me:\(port)/payment-bestbuy"
            case .paymentTargetForm: return "http://form.lvh.me:\(port)/payment-target"
            case .paymentKohlsAirbnbForm: return "http://form.lvh.me:\(port)/payment-kohls-airbnb"
            case .paymentHotelsForm: return "http://form.lvh.me:\(port)/payment-hotels"
            case .paymentExpediaForm: return "http://form.lvh.me:\(port)/payment-expedia"
            case .paymentPricelineForm: return "http://form.lvh.me:\(port)/payment-priceline"
            case .paymentHotwireForm: return "http://form.lvh.me:\(port)/payment-hotwire"
            case .paymentKayakForm: return "http://form.lvh.me:\(port)/payment-kayak"
            case .paymentAgodaForm: return "http://form.lvh.me:\(port)/payment-agoda"
            case .paymentNetflixForm: return "http://form.lvh.me:\(port)/payment-netflix"
            case .paymentDisneyForm: return "http://form.lvh.me:\(port)/payment-disney"
            case .paymentHboMaxForm: return "http://form.lvh.me:\(port)/payment-hbomax"
            case .paymentYoutubeForm: return "http://form.lvh.me:\(port)/payment-youtube"
            case .paymentSpotifyForm: return "http://form.lvh.me:\(port)/payment-spotify"
            case .paymentAppleForm: return "http://form.lvh.me:\(port)/payment-apple"
            case .paymentUberForm: return "http://form.lvh.me:\(port)/payment-uber"
            case .paymentDoordashForm: return "http://form.lvh.me:\(port)/payment-doordash"

            case .visibilityForm: return "http://form.lvh.me:\(port)/visibility"

            case .socialMediaAdBlock: return "http://social-media-adblock.test.adblock.lvh.me:\(port)/"
            case .insideAdBlock: return "http://inside-adblock.test.adblock.lvh.me:\(port)/"
            case .fullSiteAdBlock: return "http://a-stat.test.adblock.lvh.me:\(port)/"
            case .cookieBannerAdBlock: return "http://annoyances-adblock.test.adblock.lvh.me:\(port)/"
            case .popupBannerAdBlock: return "http://annoyances2-adblock.test.adblock.lvh.me:\(port)/"
            case .adsBannerAdBlock: return "http://annoyances3-adblock.test.adblock.lvh.me:\(port)/"

            case .newWindowBrowser: return "http://windowopen.browser.lvh.me:\(port)/"

            case .testPdfFile: return "http://www.lvh.me:\(port)/static/test.pdf"
            }
        }
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

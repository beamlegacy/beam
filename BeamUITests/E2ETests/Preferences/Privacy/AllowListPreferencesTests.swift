//
//  AllowListPreferencesTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 11/05/2022.
//

import Foundation
import XCTest

class AllowListPreferencesTests: BaseTest {
    
    let hostURL = "a-stat.test.adblock.lvh.me"
    let hostURLGoogle = "google.com"
    let hostURLFacebook = "facebook.com"

    let privacyWindow = PrivacyPreferencesTestView()
    
    override func setUp() {
        step ("GIVEN I open Allow list preferences"){
            super.setUp()
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .privacy)
            privacyWindow.accessAllowList()
        }
    }
    
    private func allowUrl(hostUrl: String){
        step("When I add \(hostUrl) in Allow List") {
            privacyWindow.addAllowUrl().fillNewUrl(hostUrl)
        }
    }
    
    func testAddAllowUrlItem() throws {
        testrailId("C651")
        allowUrl(hostUrl: hostURL)
        
        step("Then host \(hostURL) is correctly added") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
            privacyWindow.saveAllowList()
            privacyWindow.accessAllowList()
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
        }
        
        allowUrl(hostUrl: hostURLGoogle)
        
        step("Then host \(hostURLGoogle) is correctly added") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(1).getStringValue(), hostURLGoogle)
            privacyWindow.saveAllowList()
            privacyWindow.accessAllowList()
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(1).getStringValue(), hostURLGoogle)
        }
        
    }
    
    func testRemoveAllowUrlItem() throws {
        testrailId("C652")
        allowUrl(hostUrl: hostURL)
        
        step("And I save Allow List") {
            privacyWindow.saveAllowList().accessAllowList()
        }
        
        step("And I delete \(hostURL)") {
            privacyWindow.selectAllowedUrlCell(hostURL).removeAllowUrl()
        }
        
        step("Then host \(hostURL) is correctly deleted") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
            privacyWindow.saveAllowList().accessAllowList()
            XCTAssertFalse(privacyWindow.isAllowListFilled())
        }
    }
    
    func testSortAllowUrlItem() throws {
        testrailId("C655")
        allowUrl(hostUrl: hostURL)
        allowUrl(hostUrl: hostURLGoogle)
        allowUrl(hostUrl: hostURLFacebook)
        
        step("Then hosts are not sorted") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(1).getStringValue(), hostURLGoogle)
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(2).getStringValue(), hostURLFacebook)
        }
        
        step("When I sort host URLs") {
            privacyWindow.sortAllowedUrls()
        }
        
        step("Then hosts are sorted reverse alphabetical order") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURLGoogle)
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(1).getStringValue(), hostURLFacebook)
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(2).getStringValue(), hostURL)
        }
        
        step("When I sort host URLs") {
            privacyWindow.sortAllowedUrls()
        }
        
        step("Then hosts are sorted alphabetical order") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(1).getStringValue(), hostURLFacebook)
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(2).getStringValue(), hostURLGoogle)
        }
    }
    
    func testCancelAllowUrlOperation() {
        testrailId("C653")
        allowUrl(hostUrl: hostURL)
        
        step("Then host \(hostURL) is correctly added") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
        }
        
        step("When I cancel the action") {
            privacyWindow.cancelAllowList().accessAllowList()
        }
        
        step("Then host \(hostURL) has not been added") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
        }
        
    }
    
    func testSearchForAllowUrl() throws {
        testrailId("C650")
        allowUrl(hostUrl: hostURL)
        allowUrl(hostUrl: hostURLGoogle)
        
        step("And I search for \(hostURL)") {
            privacyWindow.searchForAllowedUrlBy(hostURL)
        }
        
        step("Then host \(hostURL) is displayed") {
            XCTAssertTrue(privacyWindow.isAllowedUrlDisplayedBy(hostURL))
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
        }
        
        step("And host \(hostURLGoogle) is not displayed") {
            XCTAssertFalse(privacyWindow.isAllowedUrlDisplayedBy(hostURLGoogle))
        }
        
    }
    
}

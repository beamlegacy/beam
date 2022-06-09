//
//  AllowListPreferencesTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 11/05/2022.
//

import Foundation
import XCTest

class AllowListPreferencesTests: BaseTest {
    
    let hostUrl = "a-stat.test.adblock.lvh.me"
    let hostUrlGoogle = "google.com"
    let hostUrlFacebook = "facebook.com"

    let privacyWindow = PrivacyPreferencesTestView()
    
    override func setUpWithError() throws {
        step ("GIVEN I open Allow list preferences"){
            launchApp()
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

        allowUrl(hostUrl: hostUrl)
        
        step("Then host \(hostUrl) is correctly added") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
            privacyWindow.saveAllowList()
            privacyWindow.accessAllowList()
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
        }
        
        allowUrl(hostUrl: hostUrlGoogle)
        
        step("Then host \(hostUrlGoogle) is correctly added") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(1)), hostUrlGoogle)
            privacyWindow.saveAllowList()
            privacyWindow.accessAllowList()
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(1)), hostUrlGoogle)
        }
        
    }
    
    func testRemoveAllowUrlItem() throws {
        
        allowUrl(hostUrl: hostUrl)
        
        step("And I save Allow List") {
            privacyWindow.saveAllowList().accessAllowList()
        }
        
        step("And I delete \(hostUrl)") {
            privacyWindow.selectAllowedUrlCell(hostUrl).removeAllowUrl()
        }
        
        step("Then host \(hostUrl) is correctly deleted") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
            privacyWindow.saveAllowList().accessAllowList()
            XCTAssertFalse(privacyWindow.isAllowListFilled())
        }
    }
    
    func testSortAllowUrlItem() throws {
        allowUrl(hostUrl: hostUrl)
        allowUrl(hostUrl: hostUrlGoogle)
        allowUrl(hostUrl: hostUrlFacebook)
        
        step("Then hosts are not sorted") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(1)), hostUrlGoogle)
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(2)), hostUrlFacebook)
        }
        
        step("When I sort host URLs") {
            privacyWindow.sortAllowedUrls()
        }
        
        step("Then hosts are sorted reverse alphabetical order") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrlGoogle)
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(1)), hostUrlFacebook)
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(2)), hostUrl)
        }
        
        step("When I sort host URLs") {
            privacyWindow.sortAllowedUrls()
        }
        
        step("Then hosts are sorted alphabetical order") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(1)), hostUrlFacebook)
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(2)), hostUrlGoogle)
        }
    }
    
    func testCancelAllowUrlOperation() throws {
        allowUrl(hostUrl: hostUrl)
        
        step("Then host \(hostUrl) is correctly added") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
        }
        
        step("When I cancel the action") {
            privacyWindow.cancelAllowList().accessAllowList()
        }
        
        step("Then host \(hostUrl) has not been added") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
        }
        
    }
    
    func testSearchForAllowUrl() throws {
        allowUrl(hostUrl: hostUrl)
        allowUrl(hostUrl: hostUrlGoogle)
        
        step("And I search for \(hostUrl)") {
            privacyWindow.searchForAllowedUrlBy(hostUrl)
        }
        
        step("Then host \(hostUrl) is displayed") {
            XCTAssertTrue(privacyWindow.isAllowedUrlDisplayedBy(hostUrl))
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
        }
        
        step("And host \(hostUrlGoogle) is not displayed") {
            XCTAssertFalse(privacyWindow.isAllowedUrlDisplayedBy(hostUrlGoogle))
        }
        
    }
    
}

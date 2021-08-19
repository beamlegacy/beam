//
//  BrowserTabUITests.swift
//  BeamUITests
//
//  Created by Remi Santos on 04/08/2021.
//

import Foundation
import CoreAudio

import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif

class BrowserTabUITests: QuickSpec {
    let app = XCUIApplication()
    var helper: BeamUITestsHelper!

    func manualBeforeTestSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.app.launch()
        self.helper = BeamUITestsHelper(self.app)
    }

    func closeTab() {
        self.app.typeKey("w", modifierFlags: .command)
    }


    func waitUntilAudioPlayingIs(_ value: Bool, timeout: TimeInterval) -> Bool {
        var count: TimeInterval = 0
        while self.isAnyAudioPlaying() != value && count < timeout {
            sleep(1)
            count += 1
        }
        return count < timeout
    }

    override func spec() {

        describe("BrowserTab Media") {
            beforeEach {
                self.manualBeforeTestSuite()
                self.continueAfterFailure = false
            }

            context("Audio") {
                func openPageAndStartPlaying() {
                    self.helper.openTestPage(page: .media)
                    expect(self.app.staticTexts["Audio ready"].firstMatch.waitForExistence(timeout: 2)) == true
                    let button = self.app.buttons["Play Audio"].firstMatch
                    button.tap()
                }

                it("detects audio") {
                    openPageAndStartPlaying()
                    let audioIndicator = self.app.images["browserTabMediaIndicator"].firstMatch
                    expect(audioIndicator.waitForExistence(timeout: 2)) == true
                    let button = self.app.buttons["Pause Audio"].firstMatch
                    button.tap()
                    audioIndicator.waitForNonExistence(timeout: 2, for: self)
                    expect(audioIndicator.exists) == false
                    self.closeTab()
                }

                it("stops audio when closing") {
                    // core audio can be a little slow to sync, so we wait a little
                    expect(self.waitUntilAudioPlayingIs(false, timeout: 10)).to(beTrue(), description: "Mac has some audio playing already. This UITest needs silence.")
                    openPageAndStartPlaying()
                    expect(self.waitUntilAudioPlayingIs(true, timeout: 10)) == true
                    self.closeTab()
                    expect(self.waitUntilAudioPlayingIs(false, timeout: 10)).to(beTrue(), description: "Tab is still playing audio, this might indicate a webView leak")
                }
            }

            context("Video") {
                func openPageAndStartPlaying() {
                    self.helper.openTestPage(page: .media)
                    expect(self.app.staticTexts["Video ready"].firstMatch.waitForExistence(timeout: 2)) == true
                    let button = self.app.buttons["Play Video"].firstMatch
                    button.tap()
                }

                it("detects video's audio") {
                    openPageAndStartPlaying()
                    let audioIndicator = self.app.images["browserTabMediaIndicator"].firstMatch
                    expect(audioIndicator.waitForExistence(timeout: 2)) == true
                    let button = self.app.buttons["Pause Video"].firstMatch
                    button.tap()
                    audioIndicator.waitForNonExistence(timeout: 2, for: self)
                    expect(audioIndicator.exists) == false
                    self.closeTab()
                }

                it("stops video when closing") {
                    // core audio can be a little slow to sync, so we wait a little
                    expect(self.waitUntilAudioPlayingIs(false, timeout: 10)).to(beTrue(), description: "Mac has some audio playing already. This UITest needs silence.")
                    openPageAndStartPlaying()
                    expect(self.waitUntilAudioPlayingIs(true, timeout: 10)) == true
                    self.closeTab()
                    expect(self.waitUntilAudioPlayingIs(false, timeout: 10)).to(beTrue(), description: "Tab is still playing audio, this might indicate a webView leak")
                }
            }
        }
    }

    /// Uses CoreAudio to fetch all audio devices (speakers, microphone, etc)
    /// and check if any of them is currently running audio from any process.
    private func isAnyAudioPlaying() -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        var propertySize: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize) == noErr else { return false }

        let numDevices = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: numDevices)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceIDs) == noErr else { return false }

        var deviceRunningAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)

        for idx in (0..<numDevices) {
            var deviceRunningPropertySize = UInt32(MemoryLayout<CChar>.size * 64)
            var isRunningInt = UInt32(MemoryLayout<CChar>.size * 64)
            var deviceRunning = false

            if AudioObjectGetPropertyData(deviceIDs[idx], &deviceRunningAddress, 0, nil, &deviceRunningPropertySize, &isRunningInt) == noErr {
                deviceRunning = isRunningInt == 1
            }

            if deviceRunning {
                return true
            }
        }
        return false
    }
}

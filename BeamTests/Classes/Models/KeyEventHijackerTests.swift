//
//  KeyEventHijackerTests.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 22/08/2022.
//

import XCTest
@testable import Beam

class KeyEventHijackerTests: XCTestCase {

    final class KeyHandler: KeyEventHijacking {
        var receivedEvents: [NSEvent] = []

        func onKeyDown(with event: NSEvent) -> Bool {
            receivedEvents.append(event)
            return true
        }
    }

    func testKeystrokeIsReceived() throws {
        let keyHandler = KeyHandler()
        KeyEventHijacker.shared.register(handler: keyHandler, forKeyCodes: [.return])

        let returnKey = try createKeyDownEvent(characters: "\n", keyCode: .return)
        NSApplication.shared.sendEvent(returnKey)
        let spaceKey = try createKeyDownEvent(characters: " ", keyCode: .space)
        NSApplication.shared.sendEvent(spaceKey)

        XCTAssertEqual(keyHandler.receivedEvents.count, 1)
        let receivedEvent = try XCTUnwrap(keyHandler.receivedEvents.first)
        XCTAssertEqual(receivedEvent.type, .keyDown)
        XCTAssertEqual(receivedEvent.keyCode, KeyCode.return.rawValue)
    }

    func testKeyHandlersAreUnregistered() throws {
        let keyHandler1 = KeyHandler()
        KeyEventHijacker.shared.register(handler: keyHandler1, forKeyCodes: [.one])
        KeyEventHijacker.shared.register(handler: keyHandler1, forKeyCodes: [.two])
        let keyHandler2 = KeyHandler()
        KeyEventHijacker.shared.register(handler: keyHandler2, forKeyCodes: [.three])
        KeyEventHijacker.shared.register(handler: keyHandler2, forKeyCodes: [.four])

        let keyOne = try createKeyDownEvent(characters: "1", keyCode: .one)
        let keyTwo = try createKeyDownEvent(characters: "2", keyCode: .two)
        let keyThree = try createKeyDownEvent(characters: "3", keyCode: .three)
        let keyFour = try createKeyDownEvent(characters: "4", keyCode: .four)

        NSApplication.shared.sendEvent(keyOne)
        NSApplication.shared.sendEvent(keyTwo)
        NSApplication.shared.sendEvent(keyThree)
        NSApplication.shared.sendEvent(keyFour)

        XCTAssertEqual(keyHandler1.receivedEvents.count, 2)
        XCTAssertEqual(keyHandler2.receivedEvents.count, 2)

        KeyEventHijacker.shared.unregister(handler: keyHandler1)

        NSApplication.shared.sendEvent(keyOne)
        NSApplication.shared.sendEvent(keyTwo)
        NSApplication.shared.sendEvent(keyThree)
        NSApplication.shared.sendEvent(keyFour)

        XCTAssertEqual(keyHandler1.receivedEvents.count, 2)
        XCTAssertEqual(keyHandler2.receivedEvents.count, 4)
    }

    private func createKeyDownEvent(characters: String, keyCode: KeyCode) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode.rawValue))
    }
}

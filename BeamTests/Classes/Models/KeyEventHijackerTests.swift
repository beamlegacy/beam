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

        let returnKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, characters: "\n", charactersIgnoringModifiers: "\n", isARepeat: false, keyCode: KeyCode.return.rawValue))
        NSApplication.shared.sendEvent(returnKey)
        let spaceKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: KeyCode.space.rawValue))
        NSApplication.shared.sendEvent(spaceKey)

        XCTAssertEqual(keyHandler.receivedEvents.count, 1)
        let receivedEvent = try XCTUnwrap(keyHandler.receivedEvents.first)
        XCTAssertEqual(receivedEvent.type, .keyDown)
        XCTAssertEqual(receivedEvent.keyCode, KeyCode.return.rawValue)
    }
}

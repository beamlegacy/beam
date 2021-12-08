//
//  ShortcutsHelper.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation
import XCTest

class ShortcutsHelper {
    
    private func invokeCMDKey(_ key: String) {
        XCUIApplication().typeKey(key, modifierFlags:.command)
    }
    
    private func invokeCMDOptionKey(_ key: String) {
        XCUIApplication().typeKey(key, modifierFlags:[.command, .option])
    }
    
    private func invokeCMDShiftKey(_ key: String) {
        XCUIApplication().typeKey(key, modifierFlags:[.command, .shift])
    }
    
    private func invokeCMDKey(_ key: XCUIKeyboardKey) {
        XCUIApplication().typeKey(key, modifierFlags:[.command])
    }
    
    private func invokeCMDOptionKey(_ key: XCUIKeyboardKey) {
        XCUIApplication().typeKey(key, modifierFlags:[.command, .option])
    }
    
    private func invokeCMDShiftKey(_ key: XCUIKeyboardKey) {
        XCUIApplication().typeKey(key, modifierFlags:[.command, .shift])
    }
    
    private func invokeShiftKey(_ key: String) {
        XCUIApplication().typeKey(key, modifierFlags:.shift)
    }
    
    private func invokeShiftKey(_ key: XCUIKeyboardKey) {
        XCUIApplication().typeKey(key, modifierFlags:.shift)
    }
    
    enum ShortcutCommand {
        case selectAll
        case undo
        case redo
        case copy
        case paste
        case cut
        case search
        case openPreferences
        case showJournal
        case showAllCards
        case instantSearch
        case switchBetweenCardWeb
        case foldBullet
        case unfoldBullet
        case newTab
        case closeTab
        case reloadPage
        case reOpenClosedTab
        case jumpToNextTab
        case jumpToPreviousTab
        case jumpToLastTab
        case zoomIn
        case zoomOut
        case changeDestinationCard
        case quitApp
        case close
        case closeWindow
        case collectFullPage
        case endOfLine
        case beginOfLine
        case beginOfNote
        case selectOnLeft
        case selectOnRight
    }
    
    @discardableResult
    func shortcutActionInvokeRepeatedly(action: ShortcutCommand, numberOfTimes: Int) -> BaseView {
        for _ in 1...numberOfTimes {
            self.shortcutActionInvoke(action: action)
        }
        return BaseView()
    }
    
    @discardableResult
    func shortcutActionInvoke(action: ShortcutCommand) -> BaseView {
        switch action {
        case .selectAll: invokeCMDKey("a")
        case .undo: invokeCMDKey("z")
        case .redo: invokeCMDShiftKey("z")
        case .copy: invokeCMDKey("c")
        case .paste: invokeCMDKey("v")
        case .cut: invokeCMDKey("x")
        case .search: invokeCMDKey("f")
        case .openPreferences: invokeCMDKey(",")
        case .showJournal: invokeCMDShiftKey("j")
        case .showAllCards: invokeCMDShiftKey("h")
        case .instantSearch: invokeCMDKey(.return)
        case .switchBetweenCardWeb: invokeCMDKey("d")
        case .foldBullet: invokeCMDKey(.upArrow)
        case .unfoldBullet: invokeCMDKey(.downArrow)
        case .newTab: invokeCMDKey("t")
        case .closeTab: invokeCMDKey("w")
        case .reloadPage: invokeCMDKey("r")
        case .reOpenClosedTab: invokeCMDShiftKey("t")
        case .jumpToNextTab: invokeCMDShiftKey("]")
        case .jumpToPreviousTab: invokeCMDShiftKey("[")
        case .jumpToLastTab: invokeCMDKey("9")
        case .zoomIn: invokeCMDKey("+")
        case .zoomOut: invokeCMDKey("-")
        case .changeDestinationCard: invokeCMDShiftKey("d")
        case .quitApp: invokeCMDKey("q")
        case .close: invokeCMDKey("w")
        case .closeWindow: invokeCMDShiftKey("w")
        case .collectFullPage: invokeCMDKey("s")
        case .endOfLine: invokeCMDKey(.rightArrow)
        case .beginOfLine: invokeCMDKey(.leftArrow)
        case .selectOnRight: invokeShiftKey(.rightArrow)
        case .selectOnLeft: invokeShiftKey(.leftArrow)
        case .beginOfNote: invokeCMDKey(.upArrow)
        }
        return BaseView()
    }
    
}

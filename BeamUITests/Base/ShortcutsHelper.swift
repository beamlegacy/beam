//
//  ShortcutsHelper.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation
import XCTest

class ShortcutsHelper {
    
    public func invokeCMDKey(_ key: String) {
        XCUIApplication().typeKey(key, modifierFlags: .command)
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
    
    private func invokeOptionKey(_ key: XCUIKeyboardKey) {
        XCUIApplication().typeKey(key, modifierFlags: .option)
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
    
    private func invokeCntrlOptionCmdFunctionKey(_ key: XCUIKeyboardKey) {
        XCUIApplication().typeKey(key, modifierFlags:[.command, .option, .control, .function])
    }
    
    private func invokeCntrlCMDKey(_ key: String) {
        XCUIApplication().typeKey(key, modifierFlags:[.control, .command])
    }
    
    enum ShortcutCommand {
        case selectAll
        case undo
        case redo
        case copy
        case paste
        case cut
        case search
        case instantTextSearch
        case openPreferences
        case openLocation
        case showJournal
        case showAllNotes
        case instantSearch
        case switchBetweenNoteWeb
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
        case changeDestinationNote
        case quitApp
        case close
        case closeWindow
        case collectFullPage
        case endOfLine
        case beginOfLine
        case beginOfNote
        case selectOnLeft
        case selectOnRight
        case moveBulletDown
        case moveBulletUp
        case newWindow
        case newIncognitoWindow
        case showOmnibox
        case removeLastWord
        case removeEntireLine
        case unindent
        case browserHistoryForwardArrow
        case browserHistoryBackArrow
        case browserHistoryForward
        case browserHistoryBack
        case insertLink
        case pinUnpinNote
        case codeBlock
        case outOfCodeBlock
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
        case .instantTextSearch: invokeCMDKey("e")
        case .openPreferences: invokeCMDKey(",")
        case .openLocation: invokeCMDKey("l")
        case .showJournal: invokeCMDShiftKey("j")
        case .showAllNotes: invokeCMDShiftKey("h")
        case .instantSearch: invokeCMDKey(.return)
        case .switchBetweenNoteWeb: invokeCMDKey("d")
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
        case .changeDestinationNote: invokeCMDShiftKey("d")
        case .quitApp: invokeCMDKey("q")
        case .close: invokeCMDKey("w")
        case .closeWindow: invokeCMDShiftKey("w")
        case .collectFullPage: invokeCMDKey("s")
        case .endOfLine: invokeCMDKey(.rightArrow)
        case .beginOfLine: invokeCMDKey(.leftArrow)
        case .selectOnRight: invokeShiftKey(.rightArrow)
        case .selectOnLeft: invokeShiftKey(.leftArrow)
        case .beginOfNote: invokeCMDKey(.upArrow)
        case .moveBulletDown: invokeCntrlOptionCmdFunctionKey(.downArrow)
        case .moveBulletUp: invokeCntrlOptionCmdFunctionKey(.upArrow)
        case .newWindow: invokeCMDKey("n")
        case .newIncognitoWindow: invokeCMDShiftKey("n")
        case .showOmnibox: invokeCMDKey("k")
        case .removeLastWord: invokeOptionKey(.delete)
        case .removeEntireLine: invokeCMDKey(.delete)
        case .unindent: invokeShiftKey(.tab)
        case .browserHistoryForwardArrow: invokeCMDKey(.rightArrow)
        case .browserHistoryBackArrow: invokeCMDKey(.leftArrow)
        case .browserHistoryForward: invokeCMDKey("]")
        case .browserHistoryBack: invokeCMDKey("[")
        case .insertLink: invokeCntrlCMDKey("k")
        case .pinUnpinNote: invokeCMDOptionKey("p")
        case .codeBlock: invokeCntrlCMDKey("c")
        case .outOfCodeBlock: invokeShiftKey(.enter)
        }
        return BaseView()
    }
    
}

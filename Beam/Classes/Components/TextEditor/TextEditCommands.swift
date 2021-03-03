//
//  TextEditCommands.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/10/2020.
//

import Foundation

extension TextRoot {
    struct CommandDefinition {
        var undo: Bool
        var redo: Bool
        var coalesce: Bool
        var name: String
    }

    // Command system
    public enum Command {
        case none

        case insertText

        case moveForward
        case moveRight
        case moveBackward
        case moveLeft
        case moveUp
        case moveDown
        case moveWordForward
        case moveWordBackward
        case moveToBeginningOfLine
        case moveToEndOfLine

        case centerSelectionInVisibleArea

        case moveBackwardAndModifySelection
        case moveForwardAndModifySelection
        case moveWordForwardAndModifySelection
        case moveWordBackwardAndModifySelection
        case moveUpAndModifySelection
        case moveDownAndModifySelection

        case moveToBeginningOfLineAndModifySelection
        case moveToEndOfLineAndModifySelection

        case moveWordRight
        case moveWordLeft
        case moveRightAndModifySelection
        case moveLeftAndModifySelection
        case moveWordRightAndModifySelection
        case moveWordLeftAndModifySelection

        case selectAll
        case selectAllHierarchically
        case selectLine
        case selectWord

        case insertTab
        case insertNewline

        case increaseIndentation
        case decreaseIndentation

        case deleteForward
        case deleteBackward
        case deleteWordForward
        case deleteWordBackward
        case deleteToBeginningOfLine
        case deleteToEndOfLine

        case complete

        case cancelOperation
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func doCommand(_ command: Command) {
        editor.reBlink()
        switch command {
        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .moveBackward: fallthrough
        case .moveLeft:
            moveLeft()

        // swiftlint:disable:next fallthrough no_fallthrough_only
        case .moveForward: fallthrough
        case .moveRight:
            moveRight()

        case .moveLeftAndModifySelection:
            moveLeftAndModifySelection()

        case .moveWordRight:
            moveWordRight()

        case .moveWordLeft:
            moveWordLeft()

        case .moveWordRightAndModifySelection:
            moveWordRightAndModifySelection()

        case .moveWordLeftAndModifySelection:
            moveWordLeftAndModifySelection()

        case .moveRightAndModifySelection:
            moveRightAndModifySelection()

        case .moveToBeginningOfLine:
            moveToBeginningOfLine()

        case .moveToEndOfLine:
            moveToEndOfLine()

        case .moveToBeginningOfLineAndModifySelection:
            moveToBeginningOfLineAndModifySelection()

        case .moveToEndOfLineAndModifySelection:
            moveToEndOfLineAndModifySelection()

        case .moveUp:
            moveUp()

        case .moveDown:
            moveDown()

        case .moveUpAndModifySelection:
            moveUpAndModifySelection()

        case .moveDownAndModifySelection:
            moveDownAndModifySelection()

        case .increaseIndentation:
            increaseIndentation()

        case .decreaseIndentation:
            decreaseIndentation()

        case .selectAll:
            selectAllNodes()

        case .selectAllHierarchically:
            selectAllNodesHierarchically()

        case .deleteForward:
            deleteForward()

        case .deleteBackward:
            deleteBackward()

        case .insertNewline:
            insertNewline()

        default:
            break
        }

        lastCommand = command
    }
    //swiftlint:enable cyclomatic_complexity function_body_length
}

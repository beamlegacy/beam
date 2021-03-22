//
//  CommandManagerTests.swift
//  BeamTests
//
//  Created bright Jean-Louis Darmon on 19/01/2021.
//

import Foundation
import XCTest
@testable import Beam

class OperationResult {
    var res: Int = 0

    func reset() {
        self.res = 0
    }
}

class Calculator: Command<Any?> {
    static let name: String = "Calculator"
    var operand: String = ""
    var number: Int
    var opRes: OperationResult

    init(operand: String, right: Int, opRes: OperationResult) {
        self.operand = operand
        self.number = right
        self.opRes = opRes
        super.init(name: Calculator.name)
    }
    override func run(context: Any??) -> Bool {
        switch operand {
        case "+":
            self.opRes.res += self.number
        case "-":
            self.opRes.res -= self.number
        case "*":
            self.opRes.res *= self.number
        case "/":
            self.opRes.res /= self.number
        default:
            Logger.shared.logDebug("Operand is not recognized")
            return false
        }
        return true
    }

    override func undo(context: Any??) -> Bool {
        switch operand {
        case "+":
            self.opRes.res -= self.number
        case "-":
            self.opRes.res += self.number
        case "*":
            self.opRes.res /= self.number
        case "/":
            self.opRes.res *= self.number
        default:
            Logger.shared.logDebug("Operand is not recognized")
            return false
        }
        return true
    }

    override func coalesce(command: Command<Any?>) -> Bool {
        if let cmd = command as? Calculator, self.operand == cmd.operand {
            switch operand {
            case "+":
                self.number += cmd.number
            case "-":
                self.number -= cmd.number
            case "*":
                self.number *= cmd.number
            case "/":
                self.number /= cmd.number
            default:
                Logger.shared.logDebug("Can't coalesce")
                return false
            }
            return true
        } else {
            return false
        }
    }
}

class CommandManagerTests: XCTestCase {

    func testSimpleUndoRedo() throws {
        var cmdTest = ""
        let opRes = OperationResult()
        let cmdManager = CommandManager<Any?>()

        let add = Calculator(operand: "+", right: 2, opRes: opRes)
        cmdManager.run(command: add, on: nil)
        XCTAssertEqual(opRes.res, 2)
        _ = cmdManager.undo(context: nil)
        XCTAssertEqual(opRes.res, 0)

        cmdManager.run(name: "InputText", run: { (_) -> Bool in
            cmdTest = "Hello"
            return true
        }, undo: { (root) -> Bool in
            cmdTest = ""
            return true
        }, coalesce: { (root) -> Bool in
            return true
        }, on: nil)

        XCTAssertEqual(cmdTest, "Hello")
        _ = cmdManager.undo(context: nil)
        XCTAssertEqual(cmdTest, "")
        _ = cmdManager.redo(context: nil)
        XCTAssertEqual(cmdTest, "Hello")
    }

    func testSimpleGroupCommand() throws {
        var cmdTest = ""

        let cmdManager = CommandManager<Any?>()
        cmdManager.beginGroup(with: "FirstGroup")

        cmdManager.run(name: "InputText", run: { (_) -> Bool in
            cmdTest = "Hello"
            return true
        }, undo: { (root) -> Bool in
            cmdTest = ""
            return true
        }, coalesce: { (root) -> Bool in
            return false
        }, on: nil)

        cmdManager.run(name: "InputText", run: { (_) -> Bool in
            cmdTest = "\(cmdTest) this is a group"
            return true
        }, undo: { (root) -> Bool in
            cmdTest = "Hello"
            return true
        }, coalesce: { (root) -> Bool in
            return false
        }, on: nil)

        cmdManager.endGroup()

        XCTAssertEqual(cmdTest, "Hello this is a group")
        _ = cmdManager.undo(context: nil)
        XCTAssertEqual(cmdTest, "")
        _ = cmdManager.redo(context: nil)
        XCTAssertEqual(cmdTest, "Hello this is a group")

        cmdManager.endGroup()
    }

    func testSimpleCoalescing() throws {
        let cmdManager = CommandManager<Any?>()
        let opRes = OperationResult()

        let add = Calculator(operand: "+", right: 4, opRes: opRes)
        cmdManager.run(command: add, on: nil)
        XCTAssertEqual(opRes.res, 4)
        _ = cmdManager.undo(context: nil)
        XCTAssertEqual(opRes.res, 0)

        let add2 = Calculator(operand: "+", right: 6, opRes: opRes)
        if add.coalesce(command: add2) {
            cmdManager.run(command: add, on: nil)
            XCTAssertEqual(opRes.res, 10)
            _ = cmdManager.undo(context: nil)
            XCTAssertEqual(opRes.res, 0)
            _ = cmdManager.redo(context: nil)
            XCTAssertEqual(opRes.res, 10)
        }
        opRes.reset()
        let multi = Calculator(operand: "*", right: 4, opRes: opRes)
        cmdManager.run(command: multi, on: nil)
        XCTAssertEqual(multi.opRes.res, 0)
        _ = cmdManager.undo(context: nil)
        XCTAssertEqual(multi.opRes.res, 0)
        XCTAssertFalse(add2.coalesce(command: multi), "Can't coalesce Addition and Multiplication")
    }
}

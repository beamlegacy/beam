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

class Calculator: Command {
    var name: String = "Calculator"
    var operand: String = ""
    var number: Int
    var opRes: OperationResult

    init(operand: String, right: Int, opRes: OperationResult) {
        self.operand = operand
        self.number = right
        self.opRes = opRes
    }

    func run() -> Bool {
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
            print("Operand is not recognized")
            return false
        }
        return true
    }

    func undo() -> Bool {
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
            print("Operand is not recognized")
            return false
        }
        return true
    }

    func coalesce(command: Command) -> Bool {
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
                print("Can't coalesce")
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
        let cmdManager = CommandManager()

        let add = Calculator(operand: "+", right: 2, opRes: opRes)
        cmdManager.run(command: add)
        XCTAssertEqual(opRes.res, 2)
        _ = cmdManager.undo()
        XCTAssertEqual(opRes.res, 0)

        cmdManager.run(name: "InputText") { () -> Bool in
            cmdTest = "Hello"
            return true
        } undo: { () -> Bool in
            cmdTest = ""
            return true
        } coalesce: { (_) -> Bool in
            return true
        }

        XCTAssertEqual(cmdTest, "Hello")
        _ = cmdManager.undo()
        XCTAssertEqual(cmdTest, "")
        _ = cmdManager.redo()
        XCTAssertEqual(cmdTest, "Hello")
    }

    func testSimpleGroupCommand() throws {
        var cmdTest = ""

        let cmdManager = CommandManager()
        cmdManager.beginGroup(with: "FirstGroup")

        cmdManager.run(name: "InputText") { () -> Bool in
            cmdTest = "Hello"
            return true
        } undo: { () -> Bool in
            cmdTest = ""
            return true
        } coalesce: { (_) -> Bool in
            return true
        }

        cmdManager.run(name: "InputText") { () -> Bool in
            cmdTest = "\(cmdTest) this is a group"
            return true
        } undo: { () -> Bool in
            cmdTest = "Hello"
            return true
        } coalesce: { (_) -> Bool in
            return true
        }
        cmdManager.endGroup()
        
        XCTAssertEqual(cmdTest, "Hello this is a group")
        _ = cmdManager.undo()
        XCTAssertEqual(cmdTest, "")
        _ = cmdManager.redo()
        XCTAssertEqual(cmdTest, "Hello this is a group")

        cmdManager.endGroup()
    }

    func testSimpleCoalescing() throws {
        let cmdManager = CommandManager()
        let opRes = OperationResult()

        let add = Calculator(operand: "+", right: 4, opRes: opRes)
        cmdManager.run(command: add)
        XCTAssertEqual(opRes.res, 4)
        _ = cmdManager.undo()
        XCTAssertEqual(opRes.res, 0)

        let add2 = Calculator(operand: "+", right: 6, opRes: opRes)
        if add.coalesce(command: add2) {
            cmdManager.run(command: add)
            XCTAssertEqual(opRes.res, 10)
            _ = cmdManager.undo()
            XCTAssertEqual(opRes.res, 0)
            _ = cmdManager.redo()
            XCTAssertEqual(opRes.res, 10)
        }
        opRes.reset()
        let multi = Calculator(operand: "*", right: 4, opRes: opRes)
        cmdManager.run(command: multi)
        XCTAssertEqual(multi.opRes.res, 0)
        _ = cmdManager.undo()
        XCTAssertEqual(multi.opRes.res, 0)
        XCTAssertFalse(add2.coalesce(command: multi), "Can't coalesce Addition and Multiplication")
    }
}

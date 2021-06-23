//
//  CommandManagerTests.swift
//  BeamTests
//
//  Created bright Jean-Louis Darmon on 19/01/2021.
//

import Foundation
import XCTest
@testable import BeamCore

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
        }, undo: { _ -> Bool in
            cmdTest = ""
            return true
        }, coalesce: { _ -> Bool in
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
        }, undo: { _ -> Bool in
            cmdTest = ""
            return true
        }, coalesce: { _ -> Bool in
            return false
        }, on: nil)

        cmdManager.run(name: "InputText", run: { (_) -> Bool in
            cmdTest = "\(cmdTest) this is a group"
            return true
        }, undo: { _ -> Bool in
            cmdTest = "Hello"
            return true
        }, coalesce: { _ -> Bool in
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

// MARK: - Async Version

class AsyncCalculator: CommandAsync<Any?> {
    static let name: String = "AsyncCalculator"
    var operand: String = ""
    var number: Int
    var opRes: OperationResult

    init(operand: String, right: Int, opRes: OperationResult) {
        self.operand = operand
        self.number = right
        self.opRes = opRes
        super.init(name: AsyncCalculator.name)
    }

    override func run(context: Any??, completion: ((Bool) -> Void)?) {
        switch self.operand {
        case "+":
            self.opRes.res += self.number
        default:
            Logger.shared.logDebug("Operand is not recognized")
            completion?(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(100))) {
            completion?(true)
        }
    }

    override func undo(context: Any??, completion: ((Bool) -> Void)?) {
        switch self.operand {
        case "+":
            self.opRes.res -= self.number
        default:
            Logger.shared.logDebug("Operand is not recognized")
            completion?(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(100))) {
            completion?(true)
        }
    }
}

extension CommandManagerTests {
    func testAsyncSimpleUndoRedo() {
        let opRes = OperationResult()
        let cmdManager = CommandManagerAsync<Any?>()

        let add = AsyncCalculator(operand: "+", right: 2, opRes: opRes)
        let runExpectation = XCTestExpectation(description: "AsyncCalculator Run")
        cmdManager.run(command: add, on: nil) { done in
            runExpectation.fulfill()
        }
        wait(for: [runExpectation], timeout: 5)
        XCTAssertEqual(opRes.res, 2)

        let undoExpectation = XCTestExpectation(description: "AsyncCalculator Undo")
        cmdManager.undoAsync(context: nil, completion: { _ in
            undoExpectation.fulfill()
        })
        wait(for: [undoExpectation], timeout: 5)

        let redoExpectation = XCTestExpectation(description: "AsyncCalculator Redo")
        cmdManager.redoAsync(context: nil, completion: { _ in
            redoExpectation.fulfill()
        })
        wait(for: [redoExpectation], timeout: 5)
        XCTAssertEqual(opRes.res, 2)
    }

    func testAsyncForbidParallelism() {
        let opRes = OperationResult()
        let cmdManager = CommandManagerAsync<Any?>()

        let add = AsyncCalculator(operand: "+", right: 2, opRes: opRes)
        let runExpectation = XCTestExpectation(description: "AsyncCalculator Run")
        cmdManager.run(command: add, on: nil) { _ in
            runExpectation.fulfill()
        }

        wait(for: [runExpectation], timeout: 5)
        XCTAssertEqual(opRes.res, 2)

        let undoExpectation = XCTestExpectation(description: "AsyncCalculator Undo")
        cmdManager.undoAsync(context: nil, completion: { done in
            XCTAssertTrue(done)
            undoExpectation.fulfill()
        })
        let redoExpectation = XCTestExpectation(description: "AsyncCalculator Redo")
        cmdManager.redoAsync(context: nil, completion: { done in
            XCTAssertFalse(done)
            redoExpectation.fulfill()
        })
        wait(for: [undoExpectation, redoExpectation], timeout: 10)
        XCTAssertEqual(opRes.res, 0) // redo was cancelled because undo wasn't finished
    }
}

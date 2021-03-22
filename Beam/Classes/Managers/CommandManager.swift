//
//  CommandManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/01/2021.
//

import Foundation

class Command<Context> {
    var name: String
    func run(context: Context?) -> Bool { return false }
    func undo(context: Context?) -> Bool { return false }
    func coalesce(command: Command<Context>) -> Bool { return false }

    init(name: String) {
        self.name = name
    }
}

class BlockCommand<Context>: Command<Context> {
    var _run: (_ context: Context?) -> Bool
    var _undo: (_ context: Context?) -> Bool
    var _coalesce: (Command<Context>) -> Bool

    init(name: String, run: @escaping (Context?) -> Bool, undo: @escaping (Context?) -> Bool, coalesce: @escaping (Command<Context>) -> Bool) {
        self._run = run
        self._undo = undo
        self._coalesce = coalesce
        super.init(name: name)
    }

    override func run(context: Context?) -> Bool {
        return _run(context)
    }

    override func undo(context: Context?) -> Bool {
        return _undo(context)
    }

    override func coalesce(command: Command<Context>) -> Bool {
        return _coalesce(command)
    }
}

class GroupCommand<Context>: Command<Context> {
    var commands: [Command<Context>] = []

    func append(command: Command<Context>) {
        guard let lastCommand = commands.last,
            lastCommand.coalesce(command: command)
        else {
            commands.append(command)
            return
        }
    }

    override func run(context: Context?) -> Bool {
        for c in commands {
            guard c.run(context: context) else { return false }
        }
        return true
    }

    override func undo(context: Context?) -> Bool {
        for c in commands.reversed() {
            guard c.undo(context: context) else { return false }
        }
        return true
    }
}

// MARK: - CommandManager

class CommandManager<Context> {
    private var doneQueue: [Command<Context>] = []
    private var undoneQueue: [Command<Context>] = []

    private var groupCmd: [GroupCommand<Context>] = []
    private var groupFailed: Bool = false

    private var lastCmdDate: Date?

    @discardableResult
    func run(name: String, run: @escaping (Context?) -> Bool, undo: @escaping (Context?) -> Bool, coalesce: @escaping (Command<Context>) -> Bool, on context: Context) -> Bool {
        self.run(command: BlockCommand(name: name, run: run, undo: undo, coalesce: coalesce), on: context)
    }

    private func appendToDone(command: Command<Context>) {
        guard let lastGroup = groupCmd.last else {
            guard let lastCmd = doneQueue.last, lastCmd.coalesce(command: command) else {
                doneQueue.append(command)
                return
            }
            return
        }

        lastGroup.append(command: command)
    }

    @discardableResult
    func run(command: Command<Context>, on context: Context) -> Bool {
        Logger.shared.logDebug("Run: \(command.name)")
        let done = command.run(context: context)

        if done && !groupFailed {
            appendToDone(command: command)
        } else {
            Logger.shared.logDebug("\(command.name) run failed")
            guard groupCmd.isEmpty else {
                groupFailed = true
                endGroup()
                return false
            }
        }
        return done
    }

    func undo(context: Context?) -> Bool {
        guard groupCmd.isEmpty else {
            fatalError("Cannot Undo with a GroupCommand active, it should be ended first.")
        }

        guard let lastCmd = doneQueue.last else { return false }
        Logger.shared.logDebug("Undo: \(lastCmd.name)")

        guard lastCmd.undo(context: context) else {
            Logger.shared.logDebug("\(lastCmd.name) undo failed")
            return false
        }

        undoneQueue.append(lastCmd)
        doneQueue.removeLast()
        return true
    }

    func redo(context: Context?) -> Bool {
        guard groupCmd.isEmpty else {
            fatalError("Cannot Redo with a GroupCommand active, it should be ended first.")
        }

        guard let lastCmd = undoneQueue.last else { return false }
        Logger.shared.logDebug("Redo: \(lastCmd.name)")

        guard lastCmd.run(context: context) else {
            Logger.shared.logDebug("\(lastCmd.name) redo failed")
            return false
        }

        doneQueue.append(lastCmd)
        undoneQueue.removeLast()
        return true
    }

    // MARK: - Group Command
    func beginGroup(with name: String) {
        guard groupCmd.isEmpty else { return }
        groupFailed = false
        groupCmd.append(GroupCommand(name: name))
    }

    func endGroup() {
        guard let lastGrp = groupCmd.last else { return }
        doneQueue.append(lastGrp)
        groupCmd.removeLast()
    }

    // MARK: - Timer
    func getTimeInterval() -> TimeInterval? {
        guard let lastCmdDate = self.lastCmdDate else {
            self.lastCmdDate = Date()
            return nil
        }
        return Date().timeIntervalSince(lastCmdDate)
    }
}

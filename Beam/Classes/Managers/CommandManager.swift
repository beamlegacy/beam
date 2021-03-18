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
        commands.append(command)
    }

    override func run(context: Context?) -> Bool {
        var running = true
        for c in commands {
            running = c.run(context: context)
            if !running { break }
        }
        return running
    }

    override func undo(context: Context?) -> Bool {
        var undoing = true
        for c in commands.reversed() {
            undoing = c.undo(context: context)
            if !undoing { break }
        }
        return undoing
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

    @discardableResult
    func run(command: Command<Context>, on context: Context) -> Bool {
        var cmdToRun = command
        if let lastCmd = doneQueue.last, lastCmd.coalesce(command: cmdToRun) {
            doneQueue.removeLast()
            cmdToRun = lastCmd
        }
        let done = cmdToRun.run(context: context)
        if done && !groupFailed {
            Logger.shared.logDebug("Run: \(cmdToRun.name)")
            guard !groupCmd.isEmpty else {
                doneQueue.append(cmdToRun)
                return true
            }
            groupCmd.last?.append(command: cmdToRun)
        } else {
            Logger.shared.logDebug("\(cmdToRun.name) run failed")
            guard groupCmd.isEmpty else {
                groupFailed = true
                endGroup()
                return false
            }
        }
        return done
    }

    func undo(context: Context?) -> Bool {
        guard !groupCmd.isEmpty else {
            guard let lastCmd = doneQueue.last else { return false }
            if lastCmd.undo(context: context) {
                Logger.shared.logDebug("Undo: \(lastCmd.name)")
                undoneQueue.append(lastCmd)
                doneQueue.removeLast()
                return true
            }
            Logger.shared.logDebug("\(lastCmd.name) undo failed")
            return false
        }
        fatalError("Cannot Undo with a GroupCommand active, it should be ended first.")
    }

    func redo(context: Context?) -> Bool {
        guard !groupCmd.isEmpty else {
            guard let lastCmd = undoneQueue.last else { return false }
            if lastCmd.run(context: context) {
                Logger.shared.logDebug("Redo: \(lastCmd.name)")
                doneQueue.append(lastCmd)
                undoneQueue.removeLast()
                return true
            }
            Logger.shared.logDebug("\(lastCmd.name) redo failed")
            return false
        }
        fatalError("Cannot Redo with a GroupCommand active, it should be ended first.")
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

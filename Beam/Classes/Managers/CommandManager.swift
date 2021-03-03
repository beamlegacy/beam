//
//  CommandManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/01/2021.
//

import Foundation

protocol Command {
    var name: String { get set }
    func run() -> Bool
    func undo() -> Bool
    func coalesce(command: Command) -> Bool
}

class BlockCommand: Command {
    var name: String
    var _run: () -> Bool
    var _undo: () -> Bool
    var _coalesce: (Command) -> Bool

    init(name: String, run: @escaping () -> Bool, undo: @escaping () -> Bool, coalesce: @escaping (Command) -> Bool) {
        self.name = name
        self._run = run
        self._undo = undo
        self._coalesce = coalesce
    }

    func run() -> Bool {
        return _run()
    }

    func undo() -> Bool {
        return _undo()
    }

    func coalesce(command: Command) -> Bool {
        return _coalesce(command)
    }
}

class GroupCommand: Command {
    var name: String
    var commands: [Command] = []

    init(name: String) {
        self.name = name
    }

    func append(command: Command) {
        commands.append(command)
    }

    func run() -> Bool {
        var running = true
        for c in commands {
            running = c.run()
            if !running { break }
        }
        return running
    }

    func undo() -> Bool {
        var undoing = true
        for c in commands.reversed() {
            undoing = c.undo()
            if !undoing { break }
        }
        return undoing
    }

    func coalesce(command: Command) -> Bool {
        return false
    }

}

// MARK: - CommandManager

class CommandManager {
    private var doneQueue: [Command] = []
    private var undoneQueue: [Command] = []

    private var groupCmd: [GroupCommand] = []
    private var groupFailed: Bool = false

    private var lastCmdDate: Date?

    func run(name: String, run: @escaping () -> Bool, undo: @escaping () -> Bool, coalesce: @escaping (Command) -> Bool) {
        self.run(command: BlockCommand(name: name, run: run, undo: undo, coalesce: coalesce))
    }

    func run(command: Command) {
        var cmdToRun = command
        if let lastCmd = doneQueue.last, lastCmd.coalesce(command: cmdToRun) {
            doneQueue.removeLast()
            cmdToRun = lastCmd
        }
        if cmdToRun.run() && !groupFailed {
            Logger.shared.logDebug("Run: \(cmdToRun.name)")
            guard !groupCmd.isEmpty else {
                doneQueue.append(cmdToRun)
                return
            }
            groupCmd.last?.append(command: cmdToRun)
        } else {
            Logger.shared.logDebug("\(cmdToRun) run failed")
            guard groupCmd.isEmpty else {
                groupFailed = true
                endGroup()
                return
            }
        }
    }

    func undo() -> Bool {
        guard !groupCmd.isEmpty else {
            guard let lastCmd = doneQueue.last else { return false }
            if lastCmd.undo() {
                Logger.shared.logDebug("Undo: \(lastCmd.name)")
                undoneQueue.append(lastCmd)
                doneQueue.removeLast()
                return true
            }
            Logger.shared.logDebug("\(lastCmd) undo failed")
            return false
        }
        fatalError("Cannot Undo with a GroupCommand active, it should be ended first.")
    }

    func redo() -> Bool {
        guard !groupCmd.isEmpty else {
            guard let lastCmd = undoneQueue.last else { return false }
            if lastCmd.run() {
                Logger.shared.logDebug("Redo: \(lastCmd.name)")
                doneQueue.append(lastCmd)
                undoneQueue.removeLast()
                return true
            }
            Logger.shared.logDebug("\(lastCmd) redo failed")
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

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

    func run(name: String, run: @escaping () -> Bool, undo: @escaping () -> Bool, coalesce: @escaping (Command) -> Bool) {
        self.run(command: BlockCommand(name: name, run: run, undo: undo, coalesce: coalesce))
    }

    func run(command: Command) {
        if command.run() && !groupFailed {
            guard !groupCmd.isEmpty else {
                doneQueue.append(command)
                return
            }
            groupCmd.last?.append(command: command)
        } else {
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
                undoneQueue.append(lastCmd)
                doneQueue.removeLast()
                return true
            }
            return false
        }
        fatalError("Cannot Undo with a GroupCommand active, it should be ended first.")
    }

    func redo() -> Bool {
        guard !groupCmd.isEmpty else {
            guard let lastCmd = undoneQueue.last else { return false }
            if lastCmd.run() {
                doneQueue.append(lastCmd)
                undoneQueue.removeLast()
                return true
            }
            return false
        }
        fatalError("Cannot Redo with a GroupCommand active, it should be ended first.")
    }

    // MARK: - Group Command

    func beginGroup(with name: String) {
        groupFailed = false
        groupCmd.append(GroupCommand(name: name))
    }

    func endGroup() {
        guard let lastGrp = groupCmd.last else { return }
        doneQueue.append(lastGrp)
        groupCmd.removeLast()
    }
}

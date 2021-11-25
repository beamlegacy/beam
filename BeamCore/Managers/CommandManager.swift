//
//  CommandManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/01/2021.
//

import Foundation
import Sentry

open class Command<Context>: Codable {
    open var name: String
    open func run(context: Context?) -> Bool { return false }
    open func undo(context: Context?) -> Bool { return false }
    open func coalesce(command: Command<Context>) -> Bool { return false }

    enum CodingKeys: String, CodingKey {
        case name
    }

    public init(name: String) {
        self.name = name
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
    }

    open func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
    }
}

public class BlockCommand<Context>: Command<Context> {
    var _run: (_ context: Context?) -> Bool
    var _undo: (_ context: Context?) -> Bool
    var _coalesce: (Command<Context>) -> Bool

    public init(name: String, run: @escaping (Context?) -> Bool, undo: @escaping (Context?) -> Bool, coalesce: @escaping (Command<Context>) -> Bool) {
        self._run = run
        self._undo = undo
        self._coalesce = coalesce
        super.init(name: name)
    }

    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    public override func run(context: Context?) -> Bool {
        return _run(context)
    }

    public override func undo(context: Context?) -> Bool {
        return _undo(context)
    }

    public override func coalesce(command: Command<Context>) -> Bool {
        return _coalesce(command)
    }
}

open class GroupCommand<Context>: Command<Context> {
    public var commands: [Command<Context>] = []

    public enum CodingKeys: String, CodingKey {
        case commands
    }

    public override init(name: String) {
        super.init(name: name)
    }

    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commands, forKey: .commands)
    }

    func append(command: Command<Context>) {
        guard let lastCommand = commands.last,
            lastCommand.coalesce(command: command)
        else {
            commands.append(command)
            return
        }
    }

    public override func run(context: Context?) -> Bool {
        for c in commands {
            guard c.run(context: context) else { return false }
        }
        return true
    }

    public override func undo(context: Context?) -> Bool {
        for c in commands.reversed() {
            guard c.undo(context: context) else { return false }
        }
        return true
    }

    public var isEmpty: Bool { commands.isEmpty }
}

// MARK: - CommandManager

public class CommandManager<Context> {
    fileprivate var doneQueue: [Command<Context>] = []
    fileprivate var undoneQueue: [Command<Context>] = []

    fileprivate var groupCmd: [GroupCommand<Context>] = []
    private var groupFailed: Bool = false

    private var lastCmdDate: Date?
    private var runningCommandLevel = 0

    public var isRunningCommand: Bool { runningCommandLevel != 0 }

    public init() {}

    @discardableResult
    public func run(name: String, run: @escaping (Context?) -> Bool, undo: @escaping (Context?) -> Bool, coalesce: @escaping (Command<Context>) -> Bool, on context: Context) -> Bool {
        self.run(command: BlockCommand(name: name, run: run, undo: undo, coalesce: coalesce), on: context)
    }

    public func appendToDone(command: Command<Context>) {
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
    public func run(command: Command<Context>, on context: Context?, needsToBeSaved: Bool = true) -> Bool {
        runningCommandLevel += 1
        defer {
            runningCommandLevel -= 1
        }

        EventsTracker.logBreadcrumb(message: "Run command \(command.name)", category: "CommandManager")
        Logger.shared.logDebug("Run: \(command.name)", category: .commandManager)
        let done = command.run(context: context)

        if done && !groupFailed && needsToBeSaved {
            appendToDone(command: command)
        } else if done && !groupFailed && !needsToBeSaved {
            return done
        } else {
            Logger.shared.logDebug("\(command.name) run failed", category: .commandManager)
            guard groupCmd.isEmpty else {
                groupFailed = true
                endGroup()
                return false
            }
        }
        return done
    }

    public func undo(context: Context?) -> Bool {
        runningCommandLevel += 1
        defer {
            runningCommandLevel -= 1
        }

        guard groupCmd.isEmpty else {
            fatalError("Cannot Undo with a GroupCommand active, it should be ended first.")
        }

        guard let lastCmd = doneQueue.last else { return false }
        EventsTracker.logBreadcrumb(message: "Undo command \(lastCmd.name)", category: "CommandManager")

        Logger.shared.logDebug("Undo: \(lastCmd.name)", category: .commandManager)

        guard lastCmd.undo(context: context) else {
            Logger.shared.logDebug("\(lastCmd.name) undo failed", category: .commandManager)
            return false
        }

        undoneQueue.append(lastCmd)
        doneQueue.removeLast()
        return true
    }

    public func redo(context: Context?) -> Bool {
        runningCommandLevel += 1
        defer {
            runningCommandLevel -= 1
        }

        guard groupCmd.isEmpty else {
            fatalError("Cannot Redo with a GroupCommand active, it should be ended first.")
        }

        guard let lastCmd = undoneQueue.last else { return false }
        EventsTracker.logBreadcrumb(message: "Redo command \(lastCmd.name)", category: "CommandManager")

        Logger.shared.logDebug("Redo: \(lastCmd.name)", category: .commandManager)

        guard lastCmd.run(context: context) else {
            Logger.shared.logDebug("\(lastCmd.name) redo failed", category: .commandManager)
            return false
        }

        doneQueue.append(lastCmd)
        undoneQueue.removeLast()
        return true
    }

    // MARK: - Group Command
    public func beginGroup(with name: String) {
        guard groupCmd.isEmpty else { return }
        groupFailed = false
        groupCmd.append(GroupCommand(name: name))
    }

    public func endGroup(forceGroup: Bool = false) {
        guard let lastGrp = groupCmd.last else { return }
        groupCmd.removeLast()
        // Prune empty group commands:
        guard !lastGrp.isEmpty else { return }
        // Skip command group if it only contains one command and directly add it
        if lastGrp.commands.count == 1, let cmd = lastGrp.commands.first, !forceGroup {
            appendToDone(command: cmd)
            return
        }
        doneQueue.append(lastGrp)
    }

    // MARK: - Timer
    public func getTimeInterval() -> TimeInterval? {
        guard let lastCmdDate = self.lastCmdDate else {
            self.lastCmdDate = BeamDate.now
            return nil
        }
        return BeamDate.now.timeIntervalSince(lastCmdDate)
    }

    public var canUndo: Bool {
        !doneQueue.isEmpty
    }

    public var canRedo: Bool {
        !undoneQueue.isEmpty
    }

    public var isEmpty: Bool {
        !canUndo && !canRedo
    }

    public var lastCmd: Command<Context>? {
        if canUndo {
            return doneQueue.last
        }
        return nil
    }
}

// MARK: - Asynchronous Commands
open class CommandAsync<Context>: Command<Context> {
    open override func run(context: Context?) -> Bool {
        run(context: context, completion: nil)
        return true
    }

    open override func undo(context: Context?) -> Bool {
        undo(context: context, completion: nil)
        return true
    }
    open func run(context: Context?, completion: ((Bool) -> Void)?) { }
    open func undo(context: Context?, completion: ((Bool) -> Void)?) { }
}

public class CommandManagerAsync<Context>: CommandManager<Context> {

    private var isRuningCommand = false

    public func run(command: CommandAsync<Context>, on context: Context?, completion: ((Bool) -> Void)?) {
        guard groupCmd.isEmpty else {
            fatalError("Async Command Manager doesn't support GroupCommand.")
        }
        Logger.shared.logDebug("Run: \(command.name)")
        command.run(context: context) { [weak self] done in
            guard let self = self else { return }
            if done {
                self.appendToDone(command: command)
            } else {
                Logger.shared.logDebug("\(command.name) run failed")
            }
            completion?(done)
        }
    }

    public func undoAsync(context: Context?, completion: ((Bool) -> Void)?) {
        guard groupCmd.isEmpty else {
            fatalError("Async Command Manager doesn't support GroupCommand.")
        }
        guard let lastCmd = doneQueue.last, !isRuningCommand else {
            completion?(false)
            return
        }
        Logger.shared.logDebug("Undo: \(lastCmd.name)")
        isRuningCommand = true
        let finishBlock: (Bool) -> Void = { [weak self] done in
            guard let self = self else { return }
            if done {
                self.undoneQueue.append(lastCmd)
                self.doneQueue.removeLast()
            } else {
                Logger.shared.logDebug("\(lastCmd.name) undo failed")
            }
            self.isRuningCommand = false
            completion?(done)
        }

        guard let lastCmdAsync = lastCmd as? CommandAsync<Context> else {
            let done = lastCmd.undo(context: context)
            finishBlock(done)
            return
        }
        lastCmdAsync.undo(context: context) { done in
            finishBlock(done)
        }
    }

    public func redoAsync(context: Context?, completion: ((Bool) -> Void)?) {
        guard groupCmd.isEmpty else {
            fatalError("Async Command Manager doesn't support GroupCommand.")
        }
        guard let lastCmd = undoneQueue.last, !isRuningCommand else {
            completion?(false)
            return
        }
        isRuningCommand = true
        Logger.shared.logDebug("Redo: \(lastCmd.name)")

        let finishBlock: (Bool) -> Void = { [weak self] done in
            guard let self = self else { return }
            if done {
                self.doneQueue.append(lastCmd)
                self.undoneQueue.removeLast()
            } else {
                Logger.shared.logDebug("\(lastCmd.name) redo failed")
            }
            self.isRuningCommand = false
            completion?(done)
        }

        guard let lastCmdAsync = lastCmd as? CommandAsync<Context> else {
            let done = lastCmd.run(context: context)
            finishBlock(done)
            return
        }
        lastCmdAsync.run(context: context) { done in
            finishBlock(done)
        }
    }
}

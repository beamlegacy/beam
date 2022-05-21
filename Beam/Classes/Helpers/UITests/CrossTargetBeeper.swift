//
//  CrossTargetBeeper.swift
//  Beam
//
//  From https://www.matrixprojects.net/p/triggering-events-while-ui-testing/
//

import Foundation

typealias BeepHandler = () -> Void

/// A basic beeper to trigger events ("beeps") between targets
protocol CrossTargetBeeper {

    /// Trigger a beep for the specified identifier
    func beep(identifier: String)

    /// Registers a beep handler for a specific identifier.
    /// Upon receiving a "beep" with the matching identifier
    /// the handler is performed
    func register(identifier: String, handler: @escaping BeepHandler)

    /// Unregister a beep handler for a specific identifier.
    /// Further "beeps" for this identifier will not
    /// cause the previously registered handler to be called
    func unregister(identifier: String)
}

// MARK: - CrossTargetNotificationCenterBeeper

/// A Cross Target Center based Beeper implementation
class CrossTargetNotificationCenterBeeper: CrossTargetBeeper {

    private let crossTargetNotificationCenter: CFNotificationCenter
    private let prefix: String
    private var handlers = [String: BeepHandler]()

    /// Constructs a CrossTargetNotificationCenter backed implementation of a "Beeper"
    ///
    /// - Parameter prefix: The prefix to use for notification names within the notification center
    ///                     to avoid any potential clashes with other applications that may also
    ///                     be using the notitication center API.
    init(prefix: String = "co.beamapp.uitests.beeper") {
        crossTargetNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        self.prefix = prefix.appending(".")
    }

    deinit {
        CFNotificationCenterRemoveObserver(crossTargetNotificationCenter,
                                           rawPointerToSelf,
                                           nil,
                                           nil)

    }

    /// Constructs a notification name from the specified identifier
    /// by wrapping it with the predefined prefix to avoid
    /// potential clashes with other applications that may be
    /// using the notification center API.
    ///
    /// - Parameter identifier: handler identifier
    /// - Returns: The prefixed notification name
    private func notificationName(from identifier: String) -> String {
        return "\(prefix)\(identifier)"
    }

    /// Extracts the identifier from the notification name
    /// by stripping out the predefined prefix.
    ///
    /// - Parameter name: The notification name provided by the notification center
    /// - Returns: The beep identifier (delt with publicly)
    private func identifier(from name: String) -> String {
        guard let prefixRange = name.range(of: prefix) else {
            return name
        }
        return String(name[prefixRange.upperBound...])
    }

    fileprivate func handleNotification(name: String) {
        let handlerIdentifier = identifier(from: name)
        if let handler = handlers[handlerIdentifier] {
            handler()
        }
    }

    private var rawPointerToSelf: UnsafeRawPointer {
        return UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    // MARK: - CrossTargetBeeper

    func beep(identifier: String) {
        let name = notificationName(from: identifier)
        CFNotificationCenterPostNotification(crossTargetNotificationCenter,
                                             CFNotificationName(name as CFString),
                                             nil,
                                             nil,
                                             true)
    }

    func register(identifier: String, handler: @escaping BeepHandler) {
        handlers[identifier] = handler
        let name = notificationName(from: identifier)
        CFNotificationCenterAddObserver(crossTargetNotificationCenter,
                                        rawPointerToSelf,
                                        handleDarwinNotification,
                                        name as CFString,
                                        nil,
                                        .deliverImmediately)

    }

    func unregister(identifier: String) {
        handlers[identifier] = nil
        let name = notificationName(from: identifier)
        let cfNotificationName = CFNotificationName(name as CFString)
        CFNotificationCenterRemoveObserver(crossTargetNotificationCenter,
                                           rawPointerToSelf,
                                           cfNotificationName,
                                           nil)
    }
}

private func handleDarwinNotification(notificationCenteR: CFNotificationCenter?,
                                      observer: UnsafeMutableRawPointer?,
                                      notificationName: CFNotificationName?,
                                      unusedObject: UnsafeRawPointer?,
                                      unusedUserInfo: CFDictionary?) {
    guard let observer = observer,
        let notificationName = notificationName else {
            return
    }
    let beeper = Unmanaged<CrossTargetNotificationCenterBeeper>.fromOpaque(observer).takeUnretainedValue()
    let name = (notificationName.rawValue as String)
    beeper.handleNotification(name: name)
}

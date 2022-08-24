//
//  KeyEventHijacker.swift
//  Beam
//
//  Created by Frank Lefebvre on 28/07/2022.
//

import AppKit

protocol KeyEventHijacking: AnyObject {
    /// Keystroke handling method
    /// - Parameter event: the keystroke event (type = `.keyDown`, the key itself can be retrieved through `event.keyCode`)
    /// - Returns: `true` if the key has been handled, `false` to send it to the responder chain
    func onKeyDown(with event: NSEvent) -> Bool
}

/// Keystroke hijack utility
///
/// This class allows to capture keystrokes before they reach the first responder (typically the focused text field),
/// and to forward them to the currently registered handler.
/// It is supposed to be used through its `shared` instance.
/// Handlers can register interest for a given list of key codes. They are registered until either unregister explicitly or deallocated.
final class KeyEventHijacker {
    private final class WeakRef<T> {
        private weak var internalValue: AnyObject?

        init<Object: AnyObject>(_ value: Object) {
            internalValue = value
        }

        var value: T? {
            internalValue as? T
        }
    }

    static let shared = KeyEventHijacker()

    private var registry = [UInt16: WeakRef<KeyEventHijacking>]()

    /// Register a handler for a list of keycodes
    ///
    /// - Lifecycle: the registry keeps a weak reference to the handler.
    /// - Only one handler can intercept a given key at a time. Registering another handler for an already registered key will cancel the previous handler for that key.
    /// - Parameters:
    ///   - handler: the handler object
    ///   - keyCodes: the list of key codes to forward to `onKeyDown`
    func register<T>(handler: T, forKeyCodes keyCodes: [KeyCode]) where T: KeyEventHijacking {
        for keyCode in keyCodes {
            registry[keyCode.rawValue] = WeakRef(handler)
        }
    }

    /// Unregister a handler
    /// - Parameter handler: the handler to unregister
    func unregister(handler: KeyEventHijacking) {
        let keysToRemove = registry
            .filter { $0.value === handler }
            .map(\.key)
        for key in keysToRemove {
            registry[key] = nil
        }
    }

    fileprivate func handleKeyDown(with event: NSEvent) -> Bool {
        assert(event.type == .keyDown)
        guard let handler = registry[event.keyCode]?.value else { return false }
        return handler.onKeyDown(with: event)
    }
}

extension BeamApplication {
    override public func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && KeyEventHijacker.shared.handleKeyDown(with: event) {
            return
        }
        super.sendEvent(event)
    }
}

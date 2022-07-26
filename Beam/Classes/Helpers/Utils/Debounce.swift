//
//  Debounce.swift
//  Beam

import Foundation
import Combine
import SwiftUI

/**
 Wraps a function in a new function that will only execute the wrapped function if `delay` has passed without this function being called.

 - Parameter delay: A `DispatchTimeInterval` to wait before executing the wrapped function after last invocation.
 - Parameter queue: The queue to perform the action on. Defaults to the main queue.
 - Parameter action: A function to debounce. Can't accept any arguments.

 - Returns: A new function that will only call `action` if `delay` time passes between invocations.

 Created by Simon Ljungberg on 19/12/16.
 License: MIT
 */
func debounce(delay: DispatchTimeInterval, queue: DispatchQueue = .main, action: @escaping (() -> Void)) -> () -> Void {
    var currentWorkItem: DispatchWorkItem?
    return {
        currentWorkItem?.cancel()
        currentWorkItem = DispatchWorkItem { action() }
        queue.asyncAfter(deadline: .now() + delay, execute: currentWorkItem!)
    }
}

/**
 Create a publisher that will only publish when `delay` has passed.

 Using it with `.sink` and `.store` to get a cancellable debounced event.

 - Parameter delay: A `DispatchTimeInterval` to wait before publishing.

 - Returns: A new `AnyPublisher` that will publish after the `delay` time passes.
 */
func debouncePublisher(delay: DispatchTimeInterval) -> AnyPublisher<Any, Never> {
    Future { promise in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            promise(.success(true))
        }
    }.eraseToAnyPublisher()
}

extension View {
    /**
     Wrapper for View.onPreferenceChange() that will perform the action only if a delay has passed since the last preference change was received.
     */
    @inlinable public func onPreferenceChangeDebounced<K>(_ key: K.Type = K.self, delay: DispatchTimeInterval, queue: DispatchQueue = .main, perform action: @escaping (K.Value) -> Void) -> some View where K : PreferenceKey, K.Value : Equatable {
        var currentWorkItem: DispatchWorkItem?
        return self.onPreferenceChange(key) { v in
            currentWorkItem?.cancel()
            currentWorkItem = DispatchWorkItem { action(v) }
            queue.asyncAfter(deadline: .now() + delay, execute: currentWorkItem!)
        }
    }
}

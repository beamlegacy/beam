//
//  NSAlert+async.swift
//  Beam
//
//  Created by Jérôme Blondon on 26/07/2022.
//

import Foundation

extension NSAlert {
    /**
    Workaround to allow using `NSAlert` in a `Task`.

    [FB9857161](https://github.com/feedback-assistant/reports/issues/288)
    */
    @MainActor
    @discardableResult
    func run() async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                continuation.resume(returning: runModal())
            }
        }
    }
}

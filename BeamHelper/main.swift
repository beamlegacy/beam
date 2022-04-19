//
//  BeamHelper.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/12/2021.
//

import Foundation
import AppKit

autoreleasepool {
    guard let parentPID = Int32(CommandLine.arguments[1]) else {
        fatalError("Relaunch: parentPID == nil.")
    }

    if let app = NSRunningApplication(processIdentifier: parentPID) {

        let bundleURL = app.bundleURL!

        let observation = app.observe(\.isTerminated) { _, _ in
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        CFRunLoopRun() // wait KVO notification
        observation.invalidate()

        // NSWorkspace.shared doesn't seems to work so I had to user this way to start Beam
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "open \"\(bundleURL.path)\""]
        task.launch()
    }
}

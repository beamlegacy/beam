//
//  BeamHelper.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/12/2021.
//

import Foundation
import AppKit

class Observer: NSObject {

    let _callback: () -> Void

    init(callback: @escaping () -> Void) {
        _callback = callback
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        _callback()
    }
}

autoreleasepool {
    guard let parentPID = Int32(CommandLine.arguments[1]) else {
        fatalError("Relaunch: parentPID == nil.")
    }

    if let app = NSRunningApplication(processIdentifier: parentPID) {

        let bundleURL = app.bundleURL!

        let listener = Observer { CFRunLoopStop(CFRunLoopGetCurrent()) }
        app.addObserver(listener, forKeyPath: "isTerminated", context: nil)
        CFRunLoopRun() // wait KVO notification
        app.removeObserver(listener, forKeyPath: "isTerminated", context: nil)

        // NSWorkspace.shared doesn't seems to work so I had to user this way to start Beam
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "open \"\(bundleURL.path)\""]
        task.launch()
    }
}

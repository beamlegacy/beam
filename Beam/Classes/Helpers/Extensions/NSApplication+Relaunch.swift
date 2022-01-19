//
//  NSApplication+Relaunch.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/12/2021.
//

import Foundation

// From
// https://stackoverflow.com/questions/27479801/restart-application-programmatically/39591935
extension NSApplication {
    func relaunch() {
        let task = Process()
        task.launchPath = Bundle.main.url(forAuxiliaryExecutable: "BeamHelper")?.path
        task.arguments = [String(ProcessInfo.processInfo.processIdentifier)]
        task.launch()
        // Ugly but I have to do this since Beam is sandboxed and I cannot terminate the app via the BeamHelper
        sleep(1)
        NSApp.terminate(self)
    }
}

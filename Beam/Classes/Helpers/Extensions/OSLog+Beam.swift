import os.log

/// Based on https://www.avanderlee.com/debugging/oslog-unified-logging/
extension OSLog {
    private static var subsystem = Configuration.bundleIdentifier

    /// Logs the view cycles like viewDidLoad.
    static let viewCycle = OSLog(subsystem: subsystem, category: "viewcycle")

    /// Logs the network calls
    static let network = OSLog(subsystem: subsystem, category: "network")

    /// Logs the network calls
    static let perf = OSLog(subsystem: subsystem, category: "perf")

    /// Logs the nonFatalError
    static let nonFatalError = OSLog(subsystem: subsystem, category: "non_fatal_error")

    /// Logs memory calls (deinit)
    static let memory = OSLog(subsystem: subsystem, category: "memory")
}

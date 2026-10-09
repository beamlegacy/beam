//
//  BeamURLSession.swift
//  Beam
//

import Foundation

/// URL session used for Beam's own requests (e.g. search suggestions). Replaceable in tests.
enum BeamURLSession {
    static var shared = URLSession(configuration: .default)

    static func reset() {
        shared = URLSession(configuration: .default)
    }
}

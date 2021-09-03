//
//  WebSessionizer.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 18/08/2021.
//

import Foundation

public class WebSessionnizer {
    public static var shared = WebSessionnizer()
    public static let sessionDuration: TimeInterval = 30 * 60 * 60
    private var lastSessionId = UUID()
    private var lastAccessedAt = BeamDate.now
    public var sessionId: UUID {
            let now = BeamDate.now
            if now.timeIntervalSince(lastAccessedAt) > WebSessionnizer.sessionDuration {
                lastSessionId = UUID()
            }
            lastAccessedAt = now
            return lastSessionId
        }
    }

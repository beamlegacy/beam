//
//  DispatchQueue.swift
//  Beam
//
//  Created by Thomas on 26/07/2022.
//

import Foundation

extension DispatchQueue {
    public static let userInitiated = DispatchQueue(label: "co.beamapp.user-initiated", qos: .userInitiated, autoreleaseFrequency: .workItem)
    public static let userInteractive = DispatchQueue(label: "co.beamapp.user-interactive", qos: .userInteractive, autoreleaseFrequency: .workItem)
    public static let utility = DispatchQueue(label: "co.beamapp.utility", qos: .utility, autoreleaseFrequency: .workItem)
    public static let database = DispatchQueue(label: "co.beamapp.database", autoreleaseFrequency: .workItem)
}

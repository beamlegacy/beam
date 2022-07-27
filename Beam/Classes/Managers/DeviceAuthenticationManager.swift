//
//  DeviceAuthenticationManager.swift
//  Beam
//
//  Created by Remi Santos on 20/07/2022.
//

import Foundation
import LocalAuthentication
import BeamCore

/// Helper to ask for device's user authorization to access secure content such as passwords and credit cards
final class DeviceAuthenticationManager {

    static let shared = DeviceAuthenticationManager()

    /// Do not persist! Used by Tests to disable the protection temporarily
    private var enablePwdAndCCProtection = true

    func checkDeviceAuthentication() async -> Bool {
        guard enablePwdAndCCProtection else { return true }
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "access your beam passwords")
            } catch LAError.userCancel {
                return false
            } catch {
                Logger.shared.logError("Error unlocking passwords preferences: \(error)", category: .passwordManager)
            }
        } else {
            // By default, if we can't evaluate policy, let's unlock.
            Logger.shared.logError("Could not use device authentication to unlock passwords preferences", category: .passwordManager)
            return true
        }
        return false
    }

    func deviceHasTouchID() -> Bool {
        let context = LAContext()
        return context.biometryType == .touchID
    }

    func temporarilyDisableDeviceAuthenticationProtection() {
        enablePwdAndCCProtection = false
    }

}

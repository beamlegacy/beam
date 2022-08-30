//
//  AppDelegate+UserInfos.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 24/09/2021.
//

import Foundation

extension AppDelegate {
    func getUserInfos(_ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) {
        let uiTestsAreRunning = ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument)
        let testsAreRunning = Configuration.env == .test && !uiTestsAreRunning

        guard !testsAreRunning,
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
                  completionHandler?(.success(false))
                  return
              }
        AppData.shared.currentAccount?.getUserInfos { _ in
            completionHandler?(.success(true))
        }
    }

    @MainActor
    func getUserInfosAsync() async throws -> Bool {
        let uiTestsAreRunning = ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument)
        let testsAreRunning = Configuration.env == .test && !uiTestsAreRunning

        guard !testsAreRunning,
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
                  return false
              }
        try await AppData.shared.currentAccount?.getUserInfosAsync()
        return true
    }
}

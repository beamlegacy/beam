//
//  AppDelegate+UserInfos.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 24/09/2021.
//

import Foundation

extension AppDelegate {
    func getUserInfos() {
        guard Configuration.env != "test",
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else { return }

        let accountManager = AccountManager()
        accountManager.getUserInfos()
    }
}

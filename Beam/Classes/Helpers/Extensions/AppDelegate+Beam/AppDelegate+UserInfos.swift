//
//  AppDelegate+UserInfos.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 24/09/2021.
//

import Foundation

extension AppDelegate {
    func getUserInfos(_ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) {
        guard Configuration.env != "test",
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
                  completionHandler?(.success(false))
                  return
              }
        let accountManager = AccountManager()
        accountManager.getUserInfos { _ in
            completionHandler?(.success(true))
        }
    }
}

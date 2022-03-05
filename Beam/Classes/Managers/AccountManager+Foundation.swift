// swiftlint:disable file_length

import Foundation
import BeamCore

extension AccountManager {
    @discardableResult
    func refreshToken(_ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        guard let accessToken = Persistence.Authentication.accessToken,
              let refreshToken = Persistence.Authentication.refreshToken else {
            completionHandler?(.success(false))
            return nil
        }

        do {
            return try self.userSessionRequest.refreshToken(accessToken: accessToken, refreshToken: refreshToken) { result in
                switch result {
                case .failure(let error):
                    Self.moveToSignedOff()
                    completionHandler?(.failure(error))
                case .success(let refresh):
                    guard let newAccessToken = refresh.accessToken, refresh.refreshToken != nil else {
                        Self.moveToSignedOff()
                        completionHandler?(.failure(APIRequestError.parserError))
                        return
                    }

                    Logger.shared.logInfo("Expiration \(String(describing: AuthenticationManager.expirationDate(accessToken))) -> \(String(describing: AuthenticationManager.expirationDate(newAccessToken)))", category: .accountManager)
                    EventsTracker.logBreadcrumb(message: "Refreshed access token and refresh token",
                                                       category: "app.lifecycle",
                                                       type: "system")

                    Persistence.Authentication.accessToken = refresh.accessToken
                    Persistence.Authentication.refreshToken = refresh.refreshToken
                    AuthenticationManager.shared.persistenceDidUpdate()
                    Self.moveToAuthenticated()
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .accountManager)
            Self.moveToSignedOff()
            completionHandler?(.failure(error))
        }

        return nil
    }

    @discardableResult
    func signIn(email: String,
                password: String,
                runFirstSync: Bool,
                completionHandler: ((Result<Bool, Error>) -> Void)? = nil,
                syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signIn(email: email, password: password) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .accountManager)
                    Self.moveToSignedOff()
                    completionHandler?(.failure(error))
                case .success(let signIn):
                    Persistence.Authentication.accessToken = signIn.accessToken
                    Persistence.Authentication.refreshToken = signIn.refreshToken
                    Persistence.Authentication.email = email
                    Persistence.Authentication.password = password
                    AuthenticationManager.shared.persistenceDidUpdate()
                    ThirdPartyLibrariesManager.shared.updateUser()

                    EncryptionManager.shared.privateKey(for: email)

                    // Syncing with remote API, AppDelegate needs to be called in mainthread
                    // TODO: move this syncData to a manager instead.
                    if runFirstSync {
                        DispatchQueue.main.async {
                            self.runFirstSync(useBuiltinPrivateKeyUI: true, syncCompletion: syncCompletion)
                        }
                    }

                    Self.moveToAuthenticated()
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .accountManager)
            Self.moveToSignedOff()
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func signInWithProvider(provider: IdentityRequest.Provider,
                            accessToken: String,
                            runFirstSync: Bool,
                            completionHandler: ((Result<Bool, Error>) -> Void)? = nil,
                            syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signInWithProvider(provider: provider, accessToken: accessToken) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .accountManager)
                    Self.moveToSignedOff()
                    completionHandler?(.failure(error))
                case .success(let signIn):
                    Persistence.Authentication.accessToken = signIn.accessToken
                    Persistence.Authentication.refreshToken = signIn.refreshToken
                    if Persistence.Authentication.email != signIn.me?.email {
                        Persistence.Authentication.email = signIn.me?.email
                        Persistence.Authentication.password = nil
                    }
                    EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError())
                    AuthenticationManager.shared.persistenceDidUpdate()
                    ThirdPartyLibrariesManager.shared.updateUser()

                    // Syncing with remote API, AppDelegate needs to be called in mainthread
                    // TODO: move this syncData to a manager instead.
                    if runFirstSync {
                        DispatchQueue.main.async {
                            self.runFirstSync(useBuiltinPrivateKeyUI: true, syncCompletion: syncCompletion)
                        }
                    }
                    Self.moveToAuthenticated()
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .accountManager)
            Self.moveToSignedOff()
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func signUp(_ email: String,
                _ password: String,
                _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signUp(email, password) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .accountManager)
                    completionHandler?(.failure(error))
                case .success(let signUp):
                    Logger.shared.logInfo("signUp succeeded: \(signUp.user?.email ?? "-")", category: .accountManager)
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .accountManager)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.forgotPassword(email: email) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .accountManager)
                    completionHandler?(.failure(error))
                case .success:
                    Logger.shared.logInfo("forgot Password succeeded", category: .accountManager)
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .accountManager)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func resendVerificationEmail(email: String,
                                 _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.resendVerificationEmail(email: email) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not resend verification email: \(error.localizedDescription)", category: .accountManager)
                    completionHandler?(.failure(error))
                case .success:
                    Logger.shared.logInfo("resend verification email succeeded", category: .accountManager)
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not resend verification email: \(error.localizedDescription)", category: .accountManager)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func getUserInfos(_ completionHandler: ((Result<UserInfoRequest.UserInfos, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userInfoRequest.getUserInfos { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not get user infos: \(error.localizedDescription)", category: .accountManager)
                    completionHandler?(.failure(error))
                case .success(let infos):
                    Logger.shared.logInfo("Get user infos succeeded", category: .accountManager)
                    AuthenticationManager.shared.username = infos.username
                    completionHandler?(.success(infos))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not get user infos: \(error.localizedDescription)", category: .accountManager)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func setUsername(username: String, _ completionHandler: ((Result<String, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userInfoRequest.setUsername(username: username) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not set username: \(error.localizedDescription)", category: .accountManager)
                    completionHandler?(.failure(error))
                case .success(let infos):
                    guard let username = infos.me?.username else {
                        completionHandler?(.failure(APIRequestError.parserError))
                        return
                    }
                    Logger.shared.logInfo("Set username succeeded", category: .accountManager)
                    AuthenticationManager.shared.username = username
                    completionHandler?(.success(username))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not set username: \(error.localizedDescription)", category: .accountManager)
            completionHandler?(.failure(error))
        }
        return nil
    }

    static func logout() {
        Persistence.cleanUp()
        AppDelegate.main.disconnectWebSockets()
        AuthenticationManager.shared.persistenceDidUpdate()
        moveToSignedOff()
        Logger.shared.logDebug("Logged out", category: .general)
    }

    // MARK: - Check private key
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func checkPrivateKey(useBuiltinPrivateKeyUI: Bool) -> ConnectionState {
        guard state == .authenticated || state == .privateKeyCheck else { return state }
        moveToPrivateKeyCheck()
        guard !AppDelegate.main.isRunningTests else {
            moveToSignedIn()
            return state
        }

        guard Persistence.Authentication.email != nil else {
            moveToSignedOff()
            return state
        }

        guard AuthenticationManager.shared.isAuthenticated else { return state }
        var pkStatus = PrivateKeySignatureManager.DistantKeyStatus.invalid
        do {
            pkStatus = try PrivateKeySignatureManager.shared.distantKeyStatus()
        } catch {
            Logger.shared.logError("Couldn't check the private key status: \(error)", category: .privateKeySignature)
            return state
        }

        switch pkStatus {
        case .valid:
            Logger.shared.logInfo("Matching local and distant private key was found.")
            moveToSignedIn()
            return state
        case .invalid:
            Logger.shared.logInfo("Local and distant private key are not matching. We need to ask the user.")

            moveToPrivateKeyCheck()

            if useBuiltinPrivateKeyUI {
                var validPrivateKey = false
                repeat {
                    Logger.shared.logInfo("Ask the user for a valid private key for this account", category: .privateKeySignature)
                    let alert = NSAlert()
                    alert.informativeText = "Beam needs your private key to connect to this account."
                    alert.addButton(withTitle: "Disconnect")
                    alert.addButton(withTitle: "Use encryption key")

                    // Add an input NSTextField for the prompt
                    let inputFrame = NSRect(
                        x: 0,
                        y: 0,
                        width: 300,
                        height: 24
                    )

                    let textField = NSTextField(frame: inputFrame)
                    textField.placeholderString = ("Private key")
                    textField.stringValue = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
                    alert.accessoryView = textField

                    // Display the NSAlert
                    let choice = alert.runModal()
                    switch choice {
                    case .alertSecondButtonReturn:
                        // Use the private key given by the user:
                        do {
                            var pk = textField.stringValue
                            // Let help the user here:
                            if pk.suffix(1) != "=" {
                                pk += "="
                            }
                            Logger.shared.logInfo("New private key from user: \(textField.stringValue)", category: .privateKeySignature)
                            try EncryptionManager.shared.replacePrivateKey(for: Persistence.emailOrRaiseError(), with: pk)
                            // Check the validity of the private key with the object on server:
                            let newStatus = try PrivateKeySignatureManager.shared.distantKeyStatus()
                            validPrivateKey = newStatus == .valid
                            Logger.shared.logInfo("New private key status: \(newStatus), valid = \(validPrivateKey)")
                        } catch {
                            Logger.shared.logError("Invalid private key from user: \(textField.stringValue)", category: .privateKeySignature)
                        }
                    default:
                        Logger.shared.logInfo("The user choose to not enter the private key, we logout", category: .privateKeySignature)
                        AccountManager.logout()
                        return state
                    }
                } while AuthenticationManager.shared.isAuthenticated && !validPrivateKey

                if validPrivateKey {
                    moveToSignedIn()
                }
            }

            return state
        case .none:
            Logger.shared.logInfo("No distant private key found. We will create one with the local one.")
            //UserAlert.showError(message: "No distant private key. The local one will be used", informativeText: "Virging account", buttonTitle: "Ok")

            // but first, let's try to see if the account is really empty:
            var canUploadPrivateKey = false
            do {
                let semaphore = DispatchSemaphore(value: 0)
                let request = BeamObjectRequest()
                try request.fetchAllObjectPrivateKeySignatures { result in
                    switch result {
                    case let .failure(error):
                        Logger.shared.logError("Error while fetching existing private key signatures from the server: \(error)", category: .privateKeySignature)
                    case let .success(signatures):
                        let localSignature = (try? PrivateKeySignatureManager.shared.privateKeySignature.signature.SHA256()) ?? "invalid"
                        canUploadPrivateKey = signatures.isEmpty || signatures.contains(localSignature)
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            } catch {
                canUploadPrivateKey = false
            }

            guard canUploadPrivateKey else {
                moveToPrivateKeyCheck()
                return state
            }

            let semaphore = DispatchSemaphore(value: 0)
            do {
                try PrivateKeySignatureManager.shared.saveOnNetwork(PrivateKeySignatureManager.shared.privateKeySignature) { result in
                    switch result {
                    case let .failure(error):
                        Logger.shared.logError("Error while sending the private key signature to sync. \(error)", category: .privateKeySignature)

                    case let .success(res):
                        if res {
                            Logger.shared.logInfo("Private key signature correctly synced.", category: .privateKeySignature)
                            moveToSignedIn()
                        } else {
                            Logger.shared.logInfo("Unable to sync private key signature.", category: .privateKeySignature)
                        }
                    }
                    semaphore.signal()
                }
            } catch {
                Logger.shared.logError("Unable to save private key signature on network: \(error)", category: .privateKeySignature)
                semaphore.signal()
            }
            semaphore.wait()
            return state
        }
    }

    func runFirstSync(useBuiltinPrivateKeyUI: Bool, syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        var syncCompletionCalled = false
        if AccountManager.checkPrivateKey(useBuiltinPrivateKeyUI: useBuiltinPrivateKeyUI) == .signedIn {
            // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
            AppDelegate.main.beamObjectManager.liveSync { _ in
                DispatchQueue.global(qos: .userInteractive).async {
                    let group = DispatchGroup()

                    group.enter()
                    DispatchQueue.main.async {
                        AppDelegate.main.syncDataWithBeamObject { _ in
                            group.leave()
                        }
                    }

                    group.enter()
                    DispatchQueue.main.async {
                        AppDelegate.main.getUserInfos { _ in
                            group.leave()
                        }
                    }

                    guard syncCompletionCalled == false else { return }

                    group.wait()

                    DispatchQueue.main.async {
                        syncCompletion?(.success(true))
                        syncCompletionCalled = true
                    }
                }
            }
        } else {
            Logger.shared.logInfo("Could not signin because AccountManager.checkPrivateKey failed", category: .accountManager)
        }
    }
}

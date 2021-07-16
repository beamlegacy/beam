import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Vinyl

@testable import Beam
@testable import BeamCore

class BeamTestsHelper {
    var turntable: Turntable?

    func beginNetworkRecording() {
        guard Configuration.networkStubs else { return }

        let recordingPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
        let filename = QuickSpec.current.name.c99ExtendedIdentifier
        var fullFilename = "\(recordingPath)/Logs/Beam/Vinyl/\(filename).json"

        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for Vinyl files: \(jobId)")

            fullFilename = "\(recordingPath)/Logs/Beam/Vinyl/\(jobId)/\(filename).json"
        }

        Logger.shared.logDebug("Vinyl: Using \(fullFilename)")

        let recordingMode = RecordingMode.missingVinyl(recordingPath: fullFilename)
        let configuration = TurntableConfiguration(matchingStrategy: .trackOrder,
                                                   recordingMode: ProcessInfo.processInfo.environment["CI_JOB_ID"] != nil ? .none : recordingMode)
        turntable = Turntable(vinylName: fullFilename, turntableConfiguration: configuration)

        BeamURLSession.shared = turntable!
    }

    func endNetworkRecording() {
        guard Configuration.networkStubs else { return }

        turntable?.stopRecording()
        turntable = nil
        BeamURLSession.reset()
    }

    func disableNetworkRecording() {
        guard Configuration.networkStubs else { return }

        turntable = nil
        BeamURLSession.reset()
    }

    static func login() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        waitUntil(timeout: .seconds(10)) { done in
            accountManager.signIn(email, password) { result in
                if case .failure(let error) = result {
                    fail(error.localizedDescription)
                }
                expect { try result.get() } == true
                done()
            }
        }

        let before = QuickSpec.current.continueAfterFailure
        QuickSpec.current.continueAfterFailure = false
        defer { QuickSpec.current.continueAfterFailure = before }
        if !AuthenticationManager.shared.isAuthenticated {
            fail("Not authenticated")
        }
    }

    static func logout() {
        guard AuthenticationManager.shared.isAuthenticated else { return }
        AccountManager.logout()
    }
}

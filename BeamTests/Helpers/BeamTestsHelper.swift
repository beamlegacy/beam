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
    private var turntable: Turntable?
    var testName: String = "no_test_name"

    func beginNetworkRecording(test: XCTestCase? = nil) {
        guard Configuration.networkStubs else { return }

        testName = test?.name ?? QuickSpec.current.name // ?? testName

        // Cancel today's journal throttled document save. Else we get random network calls where not expecting any,
        // and this fails with Vinyl

        let recordingPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
        var filename = testName.c99ExtendedIdentifier
        do {
            filename = try filename.SHA256()
        } catch {
            fatalError("Couldn't SHA \(filename)")
        }
        var fullFilename = "\(recordingPath)/Logs/Beam/Vinyl/\(filename).json"

        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            fullFilename = "\(recordingPath)/Logs/Beam/Vinyl/\(jobId)/\(filename).json"
        }

        Logger.shared.logDebug("Vinyl: Using \(fullFilename) from \(testName.c99ExtendedIdentifier)", category: .network)

        let recordingMode = RecordingMode.missingVinyl(recordingPath: fullFilename)
        let configuration = TurntableConfiguration(matchingStrategy: .trackOrder,
                                                   recordingMode: ProcessInfo.processInfo.environment["CI_JOB_ID"] != nil ? .none : recordingMode)
        turntable = Turntable(vinylName: fullFilename, turntableConfiguration: configuration, urlSession: BeamURLSession.shared)

        BeamURLSession.shared = turntable!
        APIRequest.clearNetworkCallsFiles()

        let expected = expectedAPIRequests()
        Logger.shared.logDebug("Expected network requests: \(expected)")
        APIRequest.expectedCallFiles = expected
    }

    func endNetworkRecording() {
        guard Configuration.networkStubs else { return }
        APIRequest.expectedCallFiles = []

        let expectedNetworkCalls = expectedAPIRequests()
        if !expectedNetworkCalls.isEmpty, expectedNetworkCalls != APIRequest.networkCallFiles {
            Logger.shared.logError("Expected network calls: \(expectedNetworkCalls)", category: .network)
            Logger.shared.logError("Current network calls: \(APIRequest.networkCallFiles)", category: .network)
            fatalError("Expected network calls is different from current network calls. Expected \(expectedNetworkCalls) and currently is \(APIRequest.networkCallFiles)")
        }
        saveAPIRequests()

        turntable?.stopRecording()
        turntable = nil
        BeamURLSession.reset()
    }

    static let encoder = JSONEncoder()
    static let decoder = BeamJSONDecoder()
    private func saveAPIRequestsFilename() -> URL {
        let recordingPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
        var filename = testName.c99ExtendedIdentifier
        do {
            filename = try filename.SHA256()
        } catch {
            fatalError("Couldn't SHA \(filename)")
        }

        var networkRequestsFilename = "\(recordingPath)/Logs/Beam/Vinyl/\(filename)_calls.json"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            networkRequestsFilename = "\(recordingPath)/Logs/Beam/Vinyl/\(jobId)/\(filename)_calls.json"
        }

        return URL(fileURLWithPath: networkRequestsFilename)
    }

    func saveAPIRequests() {
        let filename = saveAPIRequestsFilename()
        guard turntable != nil else { return }

        guard !FileManager.default.fileExists(atPath: filename.path) else { return }

        if let text = try? Self.encoder.encode(APIRequest.networkCallFiles) {
            try? text.write(to: filename)
            Logger.shared.logDebug("Wrote network requests to \(filename)")
        }
    }

    func expectedAPIRequests() -> [String] {
        guard turntable != nil else { return [] }

        let filename = saveAPIRequestsFilename()
        guard let data = try? String(contentsOf: filename, encoding: .utf8),
           let result: [String] = try? Self.decoder.decode([String].self, from: data.asData) else {
            return []
        }

        return result
    }

    func disableNetworkRecording() {
        guard Configuration.networkStubs else { return }

        APIRequest.expectedCallFiles = []
        turntable = nil
        BeamURLSession.reset()
    }

    static func login() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        waitUntil(timeout: .seconds(10)) { done in
            accountManager.signIn(email: email, password: password, runFirstSync: true, completionHandler: { result in
                if case .failure(let error) = result {
                    fail(error.localizedDescription)
                }
                expect { try result.get() } == true
                done()
            })
        }

        if let current = QuickSpec.current {
            let before = current.continueAfterFailure
            current.continueAfterFailure = false
            defer { current.continueAfterFailure = before }

            if !AuthenticationManager.shared.isAuthenticated {
                fail("Not authenticated")
            }
        } else {
            if !AuthenticationManager.shared.isAuthenticated {
                fail("Not authenticated")
            }
        }
    }

    static func logout() {
        BeamObjectManager.clearNetworkCalls()
        guard AuthenticationManager.shared.isAuthenticated else { return }
        AccountManager.logout()
    }
}

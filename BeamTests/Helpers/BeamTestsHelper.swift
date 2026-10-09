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

    /// Replays recorded HTTP responses (recording them when missing) for requests made through `BeamURLSession`.
    func beginNetworkRecording(test: XCTestCase? = nil) {
        guard Configuration.networkStubs else { return }

        testName = test?.name ?? QuickSpec.current.name

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
}

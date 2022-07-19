//
//  FeatureFlags.swift
//  Beam
//
//  Created by Adrian Tofan on 13/07/2022.
//

import Foundation
import BeamCore

public class FeatureFlags {
    static var current: FeatureFlagsValues { FeatureFlagsService.shared.values }
    static func startUpdate(refreshInterval: TimeInterval) {
        Logger.shared.logInfo("Feature flags updates started, refresh every \(refreshInterval) seconds", category: .featureFlags)
        FeatureFlagsService.shared.startUpdate(refreshInterval: refreshInterval)
    }
}

struct FeatureFlagsValues: Decodable {
    var syncEnabled: Bool
}

extension FeatureFlagsValues {
    static let defaultValues = FeatureFlagsValues(syncEnabled: true)
}

// MARK: Test only features
extension FeatureFlags {
    static func testSetSyncEnabled(_ newSyncEnabled: Bool) {
        FeatureFlagsService.shared.values.syncEnabled = newSyncEnabled
    }
}

internal class FeatureFlagsService {
    enum Errors: Error {
        case networkError(Error)
        case serverError // server failed to produce response
        case invalidOutput(Error)
    }

    static let shared: FeatureFlagsService = FeatureFlagsService(updateURL: FeatureFlagsService.updateURL)
    static var updateURL: URL = {
            guard let apiHostName = URL(string: Configuration.apiHostname)?.host else {
                fatalError("Failed to build default FeatureFlags object")
            }
            guard let updateURL = URL(string: "\(Configuration.featureFlagURL)/\(apiHostName).json") else {
                fatalError("Failed to build default FeatureFlags object")
            }
            return updateURL
    }()

    private let queue = DispatchQueue(label: "FeatureFlagsService-atomic", attributes: .concurrent)
    var internalValues: FeatureFlagsValues
    // atomic wrapper for internalValues
    // If speed becomes an issue, try using a wraped lock as explained here https://developer.apple.com/videos/play/wwdc2016/720/?time=997
    var values: FeatureFlagsValues {
        get {
            return queue.sync { internalValues }
        }
        set(newValues) {
            queue.async(flags: .barrier) {[weak self] in self?.internalValues = newValues }
        }
    }

    var didRefresh: (Result<FeatureFlagsValues, Errors>) -> Void = { result in
        Logger.shared.logInfo("Feature flags update \(result)", category: .featureFlags )
    }
    var scheduler: RepeatingScheduler?
    var dataTask: Foundation.URLSessionDataTask?

    let updateURL: URL

    init(updateURL: URL, defaultValues: FeatureFlagsValues = FeatureFlagsValues.defaultValues) {
        self.updateURL = updateURL
        self.internalValues = defaultValues
    }

    func startUpdate(refreshInterval: TimeInterval, delay: TimeInterval = 0) {
        scheduler = RepeatingScheduler.init(delay: delay, refreshInterval: refreshInterval)
        scheduler?.schedule { [weak self] in
            self?.update()
        }
    }

    func update() {
        dataTask?.cancel()

        dataTask = BeamURLSession.shared.dataTask(with: URLRequest.init(url: self.updateURL), completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.didRefresh(.failure(.networkError(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                self?.didRefresh(.failure(.serverError))
                return
            }
            guard let data = data else {
                self?.didRefresh(.failure(.serverError))
                return
            }
            do {
                let newValues = try JSONDecoder().decode(FeatureFlagsValues.self, from: data)
                self?.values = newValues
                self?.didRefresh(.success(newValues))
            } catch {
                self?.didRefresh(.failure(.invalidOutput(error)))
                return
            }
        })

        dataTask?.resume()

    }

    deinit {
        dataTask?.cancel()
    }
}

internal class RepeatingScheduler {
    let refreshInterval: TimeInterval
    let delay: TimeInterval

    private var timer: DispatchSourceTimer?

    init(delay: TimeInterval, refreshInterval: TimeInterval) {
        self.refreshInterval = refreshInterval
        self.delay = delay
    }

    func schedule(_ worker: @escaping () -> Void ) {
        timer?.cancel()
        timer =  DispatchSource.makeTimerSource(flags: .init(), queue: .global(qos: .utility))
        timer?.setEventHandler(handler: worker)
        timer?.schedule(deadline: .now() + delay, repeating: refreshInterval)
        timer?.activate()
    }

    deinit {
        timer?.cancel()
    }
}

import Foundation
import Combine
import Network
import BeamCore

// From https://khorbushko.github.io/article/2021/01/18/network-reachability.html

protocol NetworkReachabilityProvider {
    var networkStatusHandler: AnyPublisher<NetworkReachabilityStatus, Never> { get }

    func stopListening()
    func startListening() -> AnyPublisher<Bool, Never>
}

public enum NetworkReachabilityStatus: Equatable {
    case unknown
    case notReachable
    case reachable
}

final class NetworkMonitor: NetworkReachabilityProvider {
    public var networkStatusHandler: AnyPublisher<NetworkReachabilityStatus, Never> {
        reachabilityNotifier.eraseToAnyPublisher()
    }

    private var cancellable = Set<AnyCancellable>()

    private let monitor: NWPathMonitor = .init()
    private let handlerQueue: DispatchQueue = .main
    private let reachabilityNotifier: PassthroughSubject<NetworkReachabilityStatus, Never>
    let sessionConfig = URLSessionConfiguration.default

    // MARK: - Lifecycle

    public init() {
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 5.0
        reachabilityNotifier = PassthroughSubject<NetworkReachabilityStatus, Never>()
        configureListener()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public

    public func stopListening() {
        monitor.cancel()
    }

    @discardableResult
    public func startListening() -> AnyPublisher<Bool, Never> {
        monitor.start(queue: handlerQueue)
        return Just(true).eraseToAnyPublisher()
    }

    // MARK: - Private

    private func configureListener() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            switch path.status {
            case .satisfied:
                if let url = URL(string: "https://1.1.1.1") {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"

                    let urlSessionPublisher = URLSession(configuration: self.sessionConfig)
                            .dataTaskPublisher(for: request)
                            .retry(3)

                        urlSessionPublisher.map() {
                            $0.response
                        }.receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: {
                            switch $0 {
                            case .finished:
                                Logger.shared.logInfo("Outside world reachable", category: .network)
                            case .failure(let error):
                                Logger.shared.logWarning("Outside world not reachable: \(error)", category: .network)
                                self.reachabilityNotifier.send(.notReachable)
                            }
                        }, receiveValue: { response in
                            guard let httpResponse = response as? HTTPURLResponse,
                                  httpResponse.statusCode == 200 else {
                                self.reachabilityNotifier.send(.notReachable)
                                return
                            }
                            self.reachabilityNotifier.send(.reachable)
                        }).store(in: &self.cancellable)

                }
            case .unsatisfied,
                    .requiresConnection:
                self.reachabilityNotifier.send(.notReachable)
            @unknown default:
                self.reachabilityNotifier.send(.notReachable)
            }
        }
    }
}

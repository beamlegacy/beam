import Foundation
import Combine
import Network

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

    private let monitor: NWPathMonitor = .init()
    private let handlerQueue: DispatchQueue = .main
    private let reachabilityNotifier: PassthroughSubject<NetworkReachabilityStatus, Never>

    // MARK: - Lifecycle

    public init() {
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
        var networkStatus: NetworkReachabilityStatus = .unknown

        monitor.pathUpdateHandler = { [weak self] path in
            switch path.status {
            case .satisfied:
                networkStatus = .reachable
            case .unsatisfied,
                 .requiresConnection:
                networkStatus = .notReachable
            @unknown default:
                networkStatus = .notReachable
            }

            self?.reachabilityNotifier.send(networkStatus)
        }
    }
}

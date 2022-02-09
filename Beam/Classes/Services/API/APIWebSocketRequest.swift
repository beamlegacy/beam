import Foundation
import BeamCore
import Promises
import PromiseKit

// swiftlint:disable file_length

enum APIWebSocketRequestError: Error {
    case socket_not_connected
}

extension APIWebSocketRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .socket_not_connected:
            return "Socket not connected"
        }
    }
}

/*
 Web sockets use Rails ActionCable. We first need to connect, then
 subscribe with a random channel ID and then send the query, all responses
 will include that channel ID.

 Usage for all document updates:

 let socket = APIWebSocketRequest()
 socket.connect {
   socket.connectDocuments { result in
     switch result {
       case .failure(let error): break
       case .success(let document): break
     }
   }
 }
 */

class APIWebSocketRequest: APIRequest {
    // Change API route from https?://api.beamapp.co/ to wss?://api.beamapp.co/cable
    static private var cableRoute: String {
        let hosts = Configuration.apiHostname.split(separator: ":",
                                                    maxSplits: 1,
                                                    omittingEmptySubsequences: true)

        return "\(hosts[0] == "http" ? "ws" : "wss"):\(hosts[1])/cable"
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var connected: Bool = false
    private var channelIds: [UUID] = []

    private var connectHandler: (() -> Void)?
    var disconnectHandler: (() -> Void)?

    private var subscribeHandlers: [UUID: ((Swift.Result<UUID, Error>) -> Void)] = [:]
    private var queryCommandHandlers: [UUID: ((Swift.Result<String, Error>) -> Void)] = [:]
    private static var webSocketUploadedBytes: Int64 = 0
    private static var webSocketDownloadedBytes: Int64 = 0

    private var lastReceivedPing: Date?
    private var checkTimer: Timer?

    deinit {
        disconnect()
    }

    /// Connect to the Beam API web sockets
    /// - Parameter completionHandler: called once connected
    /// - Throws:
    func connect(onConnect: @escaping () -> Void,
                 onDisconnect: @escaping () -> Void) throws {
        reset()

        let request = try Self.makeUrlWebSocketRequest()
        let urlSession = URLSession(configuration: URLSessionConfiguration.default,
                                    delegate: self,
                                    delegateQueue: OperationQueue())

        webSocketTask = urlSession.webSocketTask(with: request)

        receive_messages()

        let authorization = (try? request.value(forHTTPHeaderField: "Authorization")?.SHA256()) ?? "-"
        let device = request.value(forHTTPHeaderField: "Device") ?? "-"
        logDebug("Connecting to \(Self.cableRoute). origin: \(Configuration.apiHostname), auth: \(authorization), device: \(device)")

        connectHandler = onConnect
        disconnectHandler = onDisconnect

        webSocketTask?.resume()
    }

    private func addCheckTimer() {
        // We need `connect` to be called from the main thread or it breaks the timer
        assert(Thread.isMainThread)

        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.sendPing()

            guard let lastReceivedPing = self.lastReceivedPing else {
                Logger.shared.logDebug("no last received ping", category: .webSocket)
                return
            }

            let timeDiff = BeamDate.now.timeIntervalSince(lastReceivedPing)

            guard timeDiff < 10 else {
                Logger.shared.logDebug("last received ping longer than 10sec, disconnecting",
                                       category: .webSocket)
                self.enforceDisconnect(callDisconnectHandler: true)
                return
            }

            #if DEBUG_API_1
            let timeDiffString = String(format: "%.1f", BeamDate.now.timeIntervalSince(lastReceivedPing))

            Logger.shared.logDebug("Checked last received ping: \(timeDiffString)sec",
                                   category: .webSocket)
            #endif
        }
    }

    private func sendPing() {
        guard let webSocketTask = webSocketTask else {
            Logger.shared.logError("websocket variable is nil", category: .webSocket)
            return
        }

        #if DEBUG_API_1
        Logger.shared.logDebug("Sending ping", category: .webSocket)
        #endif
        webSocketTask.sendPing { error in
            if let error = error {
                Logger.shared.logError("Error sending ping: \(error.localizedDescription)",
                                       category: .webSocket)
                self.enforceDisconnect()
                return
            }

            #if DEBUG_API_1
            Logger.shared.logDebug("Received pong", category: .webSocket)
            #endif
        }
    }

    private func enforceDisconnect(callDisconnectHandler: Bool = false) {
        self.connected = false

        checkTimer?.invalidate()
        checkTimer = nil

        if callDisconnectHandler {
            self.disconnectHandler?()
            self.disconnectHandler = nil
        }

        reset()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        enforceDisconnect()
    }

    func disconnectAndReconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        enforceDisconnect(callDisconnectHandler: true)
    }

    private func reset() {
        queryCommandHandlers = [:]
        subscribeHandlers = [:]
        connectHandler = nil
        channelIds = []
        lastReceivedPing = nil
    }

    /// Ask API for any beam objects changes, completionHandler will be call once per update received until this channel has been unsubscribed.
    /// - Parameter completionHandler: the document update
    /// - Returns: The channelId used for calling `unsubscribe()`
    @discardableResult
    func connectBeamObjects(_ completionHandler: @escaping (Swift.Result<[BeamObject], Error>) -> Void) -> UUID? {
        guard connected else {
            Logger.shared.logError("Socket isn't connected", category: .webSocket)
            completionHandler(.failure(APIWebSocketRequestError.socket_not_connected))
            return nil
        }

        guard let query = loadFile(fileName: "subscription_beam_objects_updated") else {
            fatalError("File not found")
        }

        /*
         Very async code, will in order:
         1. Subscribe and add a new ActionCable channel.
         2. Once subscribed, send the GraphQL query to track all document changes within this new channel
         3. For every query data back from the API, will call the completionHandler once with the updated document

         As long as `unsubscribe(channelId)` isn't called, the completionHandler will keep being called.
         */

        logDebug("connectBeamObjects called")

        return subscribe { [weak self] result in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let channelId):
                self?.queryCommand(channelId: channelId, query: query) { result in
                    switch result {
                    case .failure(let error):
                        completionHandler(.failure(error))
                    case .success(let message):
                        guard let inputMessage = try? self?.defaultDecoder().decode(WebSocketInputReceivedMessage.self,
                                                                                    from: message.asData),
                              let inputResult = inputMessage.message?.result else {
                                  Logger.shared.logError("Can't parse message: \(message)",
                                                         category: .webSocket)
                            return
                        }

                        guard let beamObjects = inputResult.data?.beamObjectsUpdated?.beamObjects else {
                            Logger.shared.logDebug("No beam objects!", category: .webSocket)
                            return
                        }

                        do {
                            Logger.shared.logDebug("Received \(beamObjects.count) beam objects",
                                                   category: .webSocket)

                            for beamObject in beamObjects {
                                try beamObject.decrypt()
                                try beamObject.setTimestamps()
                            }
                            completionHandler(.success(beamObjects))
                        } catch {
                            completionHandler(.failure(error))
                        }
                    }
                }
            }
        }
    }

    /// Requirement for parsing data received from the API
    private func receive_messages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                // we don't call `receive_messages()` since this is probably a final error
                Logger.shared.logError("Failed to receive message: \(error)", category: .webSocket)

                self.enforceDisconnect(callDisconnectHandler: true)
            case .success(let message):
                // `receive` method is called only once. If you want to receive following messages,
                // you must call `receive` again.
                // :(
                self.receive_messages()

                switch message {
                case .string(let text):
                    Self.webSocketDownloadedBytes += Int64(text.utf8.count)

                    self.manage_socket_received_message(text)
                case .data(let data):
                    Self.webSocketDownloadedBytes += Int64(data.count)

                    self.logDebug("Received binary but we don't handle it yet: \(data)")
                @unknown default:
                    Logger.shared.logError("Unknown: \(message)", category: .webSocket)
                }
            }
        }
    }

    /// Handling of data received by the API following a GraphQL query
    /// - Parameter messageText: ActionCable payload
    private func manage_socket_query_message(_ messageText: String) {
        guard let inputMessage = try? defaultDecoder().decode(WebSocketInputReceivedMessage.self,
                                                              from: messageText.asData) else {
            Logger.shared.logError("Could not parse message", category: .webSocket)
            return
        }

        guard let channelId = identifier(inputMessage.identifier) else {
            Logger.shared.logError("Can't find channelId in \(messageText)", category: .webSocket)
            return
        }

        guard let completionHandler = queryCommandHandlers[channelId] else {
            logDebug("Received result but no query handler: \(messageText)")
            return
        }

        completionHandler(.success(messageText))

        // ActionCable says there isn't any more data after, we can unsubscribe the channel
        if let more = inputMessage.message?.more, more == false {
            self.unsubscribe(channelId: channelId)
        }
    }

    /// Handling of `confirm_subscription` ActionCable messages.
    /// - Parameter message: Parsed ActionCable payload
    private func manage_socket_message_subscription(_ message: WebSocketMessage) {
        guard let messageIdentifier = message.identifier, let channelId = identifier(messageIdentifier) else {
            Logger.shared.logError("No identifier received for confirm_subscription", category: .webSocket)
            return
        }

        channelIds.append(channelId)

        guard let completionHandler = subscribeHandlers[channelId] else {
            Logger.shared.logError("Received confirm_subscription but no handler!", category: .webSocket)
            return
        }
        subscribeHandlers.removeValue(forKey: channelId)

        completionHandler(.success(channelId))
    }

    /// Handling of data input received by the API
    /// - Parameters:
    ///   - message: Parsed ActionCable payload
    ///   - messageText: Text based ActionCable payload
    private func manage_socket_received_message(_ messageText: String) {
        guard let message = try? self.defaultDecoder().decode(WebSocketMessage.self, from: messageText.asData) else {
            Logger.shared.logInfo("Received text: \(messageText) but can't be parsed", category: .webSocket)
            return
        }

        guard let webSocketTask = webSocketTask else {
            return
        }

        switch message.type {
        case nil:
            #if DEBUG_API_1
            logDebug(messageText)
            #endif

            // Messages without type are returns from GraphQL queries
            manage_socket_query_message(messageText)
        case .welcome:
            // Welcome types are received on connection, ActionCable is now available for use.
            connected = true
            connectHandler?()
            connectHandler = nil
            DispatchQueue.main.async {
                self.addCheckTimer()
            }
        case .ping:
            lastReceivedPing = BeamDate.now
            #if DEBUG_API_1
            logDebug(messageText)
            #endif
            // When receiving ping types from the API, we just send another ping back
            webSocketTask.sendPing { error in
                if let error = error {
                    Logger.shared.logError("Ping failed: \(error)", category: .webSocket)
                    self.enforceDisconnect()
                }
            }
        case .disconnect:
            enforceDisconnect(callDisconnectHandler: true)
        case .confirm_subscription:
            // confirm_subscription types are received after subscribing a new channel
            manage_socket_message_subscription(message)
        }
    }

    /// Returns the channelId
    /// - Parameter data: ActionCable payload
    /// - Returns: channelId
    private func identifier(_ data: String) -> UUID? {
        guard let channelId = (try? defaultDecoder().decode(ChannelIdentifier.self,
                                                            from: data.asData))?.channelId else {
            return nil
        }

        return UUID(uuidString: channelId)
    }

    /// Create an ActionCable command
    /// - Parameters:
    ///   - channelId:
    ///   - command:
    ///   - query: The GraphQL query
    /// - Returns: ActionCable payload
    private func command(_ channelId: UUID,
                         _ command: WebSocketCommand.CommandType,
                         _ query: String? = nil) -> String {
        let identifier = ChannelIdentifier(channel: "GraphqlChannel", channelId: channelId.uuidString.lowercased())
        guard let identifierString = (try? JSONEncoder().encode(identifier))?.asString else {
            fatalError("Couldn't convert to JSON")
        }

        var data: String?

        // TODO: we should be able to use variables
        if let query = query {
            let commandData = WebSocketCommand.CommandData(query: query, variables: nil)
            guard let commandDataString = (try? JSONEncoder().encode(commandData))?.asString else {
                fatalError("Couldn't convert to JSON")
            }
            data = commandDataString
        }

        let command = WebSocketCommand(command: command,
                                       identifier: identifierString,
                                       data: data)

        guard let commandString = (try? JSONEncoder().encode(command))?.asString else {
            fatalError("Couldn't convert to JSON")
        }

        return commandString
    }

    /// Sends a subscribe to ActionCable to add a new channel, returns the channelId in the completionHandler
    /// - Parameter completionHandler:
    /// - Returns: channelId
    private func subscribe(completionHandler: @escaping (Swift.Result<UUID, Error>) -> Void) -> UUID? {
        guard connected else {
            Logger.shared.logError("Socket isn't connected", category: .webSocket)
            completionHandler(.failure(APIWebSocketRequestError.socket_not_connected))
            return nil
        }

        let channelId = UUID()
        let commandString = command(channelId, .subscribe)

        send(commandString) { [weak self] error in
            if let error = error {
                Logger.shared.logError("Subscribe failed: \(error)", category: .webSocket)
                completionHandler(.failure(error))
                return
                // TODO: reconnect?
            }

            self?.subscribeHandlers[channelId] = completionHandler
        }

        return channelId
    }

    /// Unsubscribe the channel, will not get data back for this channel anymore
    /// - Parameter channelId:
    func unsubscribe(channelId: UUID) {
        guard connected else {
            Logger.shared.logError("Socket isn't connected", category: .webSocket)
            return
        }

        let commandString = command(channelId, .unsubscribe)
        queryCommandHandlers.removeValue(forKey: channelId)

        if let index = channelIds.firstIndex(of: channelId) {
            channelIds.remove(at: index)
        }

        send(commandString) { error in
            if let error = error {
                Logger.shared.logError("Unsubscribe failed: \(error)", category: .webSocket)
                // TODO: reconnect?
            }
        }
    }

    /// Calls the GraphQL query within the given channel
    /// - Parameters:
    ///   - channelId:
    ///   - query: GraphQL query
    ///   - completionHandler: Called multiple times, everytime we get data back from the API
    private func queryCommand(channelId: UUID,
                              query: String,
                              completionHandler: @escaping (Swift.Result<String, Error>) -> Void) {
        guard connected else {
            Logger.shared.logError("Socket isn't connected", category: .webSocket)
            completionHandler(.failure(APIWebSocketRequestError.socket_not_connected))
            return
        }

        // TODO: we should be able to use variables
        let commandString = command(channelId, .message, query)

        send(commandString) { [weak self] error in
            if let error = error {
                Logger.shared.logError("Query failed: \(error)", category: .webSocket)
                completionHandler(.failure(error))
            }

            self?.queryCommandHandlers[channelId] = completionHandler
        }
    }

    private func send(_ query: String, completionHandler: @escaping (Error?) -> Void) {
        #if DEBUG_API_1
        logDebug(query)
        #endif

        Self.webSocketUploadedBytes += Int64(query.utf8.count)

        webSocketTask?.send(.string(query), completionHandler: completionHandler)
    }

    private func logDebug(_ text: String) {
        Logger.shared.logDebug("[\(Self.webSocketUploadedBytes.byteSize)/\(Self.webSocketDownloadedBytes.byteSize)] \(text)",
                               category: .webSocket)
    }

    static private func makeUrlWebSocketRequest() throws -> URLRequest {
        guard let url = URL(string: Self.cableRoute) else { fatalError("Can't get URL: \(Self.cableRoute)") }

        AuthenticationManager.shared.updateAccessTokenIfNeeded()

        guard AuthenticationManager.shared.isAuthenticated,
              let accessToken = AuthenticationManager.shared.accessToken else {
                  ThirdPartyLibrariesManager.shared.nonFatalError(error: APIRequestError.notAuthenticated,
                                           addedInfo: AuthenticationManager.shared.hashTokensInfos())

            NotificationCenter.default.post(name: .networkUnauthorized, object: self)
            throw APIRequestError.notAuthenticated
        }

        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "Device": Self.deviceId.uuidString.lowercased(),
            "Origin": Configuration.apiHostname,
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Accept-Language": Locale.current.languageCode ?? "en",
            "Authorization": "Bearer " + accessToken
        ]

        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        return request
    }
}

extension APIWebSocketRequest {
    // Used by ActionCable to identify command executions and their results
    struct ChannelIdentifier: Codable {
        let channel: String
        let channelId: String
    }

    // Used for sending commands to the API
    struct WebSocketCommand: Encodable {
        // swiftlint:disable:next nesting
        enum CommandType: String, Encodable {
            case subscribe, unsubscribe, message
        }

        // swiftlint:disable:next nesting
        struct CommandData: Encodable {
            let query: String
            let variables: String?
            let action = "execute"
        }

        let command: CommandType
        let identifier: String
        var data: String?
    }

    // When receiving data back from the API, this is a generic data response used
    // to know if we should parse what we received from the API
    struct WebSocketInputReceivedMessage: Decodable {
        // swiftlint:disable:next nesting
        struct WebSocketResultData: Decodable {
            let data: WebSocketData?
        }

        // swiftlint:disable:next nesting
        struct WebSocketResult: Decodable {
            let result: WebSocketResultData?
            let more: Bool
        }
        let identifier: String
        let message: WebSocketResult?
    }

    // All potential graphql results we get from the API.
    // Subscription names will be included in the response
    struct WebSocketData: Decodable {
        // swiftlint:disable:next nesting
        struct WebSocketDataBeamObject: Decodable {
            let beamObject: BeamObject?
            let beamObjects: [BeamObject]?
        }

        // We should add all subscription here
        let beamObjectsUpdated: WebSocketDataBeamObject?
        let beamObjectUpdated: WebSocketDataBeamObject?
    }

    // ActionCable level messages
    struct WebSocketMessage: Decodable {
        // swiftlint:disable:next nesting
        enum MessageType: String, Decodable {
            case welcome, ping, disconnect, confirm_subscription
        }
        let type: MessageType?
        let identifier: String?
    }
}

extension APIWebSocketRequest: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        #if DEBUG_API_1
        logDebug("Web socket session opened!")
        #endif
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        logDebug("Web socket session closed!")

        connected = false

        for channelId in channelIds {
            queryCommandHandlers[channelId]?(.failure(APIWebSocketRequestError.socket_not_connected))
        }

        reset()
    }
}

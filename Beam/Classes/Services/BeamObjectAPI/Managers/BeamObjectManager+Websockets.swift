import Foundation
import BeamCore

extension BeamObjectManager {
    /// `handler` might be called multiple times in case of reconnection
    func liveSync(_ handler: @escaping (Bool) -> Void) {
        guard AuthenticationManager.shared.isAuthenticated else {
            Logger.shared.logDebug("websocket is disabled because the user isn't authenticated", category: .webSocket)
            handler(false)
            return
        }

        guard Configuration.websocketEnabled else {
            Logger.shared.logDebug("settings disabled websocket", category: .webSocket)
            handler(false)
            return
        }

        webSocketRequest = APIWebSocketRequest()

        guard let webSocketRequest = webSocketRequest else {
            handler(false)
            return
        }

        do {
            try webSocketRequest.connect(onConnect: {
                self.websocketRetryDelay = 0

                webSocketRequest.connectBeamObjects { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError("Received error in connectBeamObjects: \(error.localizedDescription)",
                                               category: .webSocket)
                    case .success(let beamObject):
                        do {
                            try self.parseFilteredObjects(self.filteredObjects([beamObject]))
                        } catch {
                            Logger.shared.logError(error.localizedDescription, category: .beamObject)
                        }
                    }
                }

                DispatchQueue.main.async {
                    handler(true)
                }
            }, onDisconnect: {
                webSocketRequest.disconnectHandler = nil

                /*
                 If servers restart (during deploys) or fail, we don't want *all* clients to reconnect at the same time,
                 we want to reconnect with random delays.

                 We also add more delay for each more fail
                 */

                self.websocketRetryDelay += 10 + Int.random(in: 0..<30) // Sleep 10sec + random

                self.websocketRetryDelay = min(self.websocketRetryDelay, 60*30) // Max retry set to 30mn

                Logger.shared.logWarning("Websocket disconnected, sleeping \(self.websocketRetryDelay)sec then retrying",
                                         category: .beamObjectNetwork)
                sleep(UInt32(self.websocketRetryDelay))

                self.liveSync(handler)
            })
        } catch {
            handler(false)
            Logger.shared.logError("Catched error: \(error.localizedDescription)", category: .webSocket)
        }
    }

    func disconnectLiveSync() {
        webSocketRequest?.disconnect()
        webSocketRequest = nil
    }
}

import Foundation
import BeamCore

extension BeamObjectManager {
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

        do {
            try webSocketRequest.connect {
                self.webSocketRequest.connectBeamObjects { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .webSocket)
                    case .success(let beamObjects):
                        do {
                            try self.parseFilteredObjects(self.filteredObjects(beamObjects))
                        } catch {
                            Logger.shared.logError(error.localizedDescription, category: .beamObject)

//                            AppDelegate.showMessage("Websocket object couldn't be parsed: \(error.localizedDescription). This is not normal, check the logs and ask support.")
                        }
                    }
                }

                DispatchQueue.main.async {
                    handler(true)
                }
            }
        } catch {
            handler(false)
            Logger.shared.logError(error.localizedDescription, category: .webSocket)
        }
    }

    func disconnectLiveSync() {
        webSocketRequest.disconnect()
        webSocketRequest = APIWebSocketRequest()
    }
}

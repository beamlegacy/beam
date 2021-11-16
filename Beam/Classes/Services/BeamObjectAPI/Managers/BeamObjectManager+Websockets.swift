import Foundation
import BeamCore

extension BeamObjectManager {
    func liveSync(_ handler: @escaping (Bool) -> Void) {
        guard AuthenticationManager.shared.isAuthenticated else { return }

        do {
            try webSocketRequest.connect {
                self.webSocketRequest.connectBeamObjects { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .webSocket)
                    case .success(let beamObject):
                        do {
                            try self.parseFilteredObjects(self.filteredObjects([beamObject]))
                        } catch {
                            AppDelegate.showMessage("Websocket object couldn't be parsed: \(error.localizedDescription). This is not normal, check the logs and ask support.")
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

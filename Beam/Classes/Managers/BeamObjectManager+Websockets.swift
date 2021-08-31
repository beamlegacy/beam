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
                            try self.parseObjects([beamObject])
                        } catch {
                            Logger.shared.logError("Failed parsing beamObject: \(error.localizedDescription)", category: .webSocket)
                            dump(beamObject)
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

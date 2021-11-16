import Foundation

// MARK: - For tests
extension BeamObjectManager {
    static func clearNetworkCalls() {
        #if DEBUG
        for request in Self.networkRequests {
            request.cancel()
        }
        #endif
    }

    /*
     Wrote this for our tests, and detect when we have still running network tasks on test ends. Sadly, this seems to
     not work when used with Vinyl, which doesn't implement `cancel()`.
     */
    static func isAllNetworkCallsCompleted() -> Bool {
        #if DEBUG
        for request in Self.networkRequests {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
                return false
            }
        }
        #endif
        return true
    }
}

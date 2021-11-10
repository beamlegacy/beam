import Foundation

// MARK: - For tests
extension BeamObjectManager {
    static func clearNetworkCalls() {
        for (_, request) in Self.networkRequests {
            request.cancel()
        }

        #if DEBUG
        for request in Self.networkRequestsWithoutID {
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
        for request in Self.networkRequestsWithoutID {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
                return false
            }
        }
        #endif

        for (_, request) in Self.networkRequests {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
                return false
            }
        }

        return true
    }
}

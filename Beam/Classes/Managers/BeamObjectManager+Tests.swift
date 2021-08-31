import Foundation

// MARK: - For tests
extension BeamObjectManager {
    static func clearNetworkCalls() {
        for (_, request) in Self.networkRequests {
            request.cancel()
        }

        for request in Self.networkRequestsWithoutID {
            request.cancel()
        }
    }

    /*
     Wrote this for our tests, and detect when we have still running network tasks on test ends. Sadly, this seems to
     not work when used with Vinyl, which doesn't implement `cancel()`.
     */
    static func isAllNetworkCallsCompleted() -> Bool {
        for request in Self.networkRequestsWithoutID {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
                return false
            }
        }

        for (_, request) in Self.networkRequests {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
                return false
            }
        }

        return true
    }
}

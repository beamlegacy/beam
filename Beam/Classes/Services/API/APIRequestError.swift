import Foundation

/// Minimal stub — most API cases removed with auth/sync infrastructure.
/// Kept for BeamObjectManager error handling (will be removed in Step 3).
enum APIRequestError: Error {
    case notFound
    case networkUnavailable
    case notAuthenticated
}

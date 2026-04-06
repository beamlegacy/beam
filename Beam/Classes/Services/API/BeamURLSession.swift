import Foundation

class BeamURLSession {
    static var shared: URLSession = URLSession.shared
    static func reset() {
        Self.shared = URLSession.shared
    }
}

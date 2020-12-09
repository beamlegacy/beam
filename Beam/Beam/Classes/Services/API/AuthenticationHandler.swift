import Foundation
import Alamofire

class AuthenticationHandler: RequestInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Alamofire.Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest

        setBearerToken(&request)

        completion(.success(request))
    }

    private func setBearerToken(_ request: inout URLRequest) {
        if let accessToken = AuthenticationManager.shared.accessToken {
            request.setValue("Bearer " + accessToken,
                             forHTTPHeaderField: "Authorization")
        }
    }
}

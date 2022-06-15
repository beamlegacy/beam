extension Result where Failure == Swift.Error {
    enum Error: Swift.Error {
        case unableToBuildResult
    }

    init(_ value: Success?, _ error: Failure?) {
        if let error = error {
            self = .failure(error)
        } else if let value = value {
            self = .success(value)
        } else {
            self = .failure(Error.unableToBuildResult)
        }
    }
}

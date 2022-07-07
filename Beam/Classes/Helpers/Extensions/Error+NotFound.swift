import Foundation

class BeamError {
    public static func isNotFound(_ errors: [Error]) -> Bool {
        for error in errors {
            switch error {
            case APIRequestError.notFound: break
            default: return false
            }
        }

        return true
    }

    public static func isNotFound(_ error: Error) -> Bool {
        switch error {
        case BeamObjectManagerError.multipleErrors(let errors):
            return isNotFound(errors)
        case APIRequestError.notFound:
            return true
        default:
            return false
        }
    }
}

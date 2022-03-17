//
//  Errors.swift
//  Beam
//
//  Created by Julien Plu on 09/03/2022.
//

import Foundation

public enum GCPCommonErrors: Error {
    case readError(description: String)
    case stringToDataError(description: String)
    case urlCreationError(description: String)
    case castError(description: String)
    case jsonDecodeError(description: String)

    public var localizedDescription: String {
        switch self {
        case .readError(let description):
            return description
        case .stringToDataError(let description):
            return description
        case .urlCreationError(let description):
            return description
        case .castError(let description):
            return description
        case .jsonDecodeError(let description):
            return description
        }
    }
}

public enum GCSObjectManagerErrors: Error, Equatable {
    case uploadError(description: String)
    case disabledService

    public var localizedDescription: String {
        switch self {
        case .disabledService:
            return "All the GCP related tasks are disabled."
        case .uploadError(let description):
            return description
        }
    }
}

public enum GCPAuthenticationManagerErrors: Error {
    case authentError(description: String)
    case privateKeyError(description: String)
    case signatureError(description: String)

    public var localizedDescription: String {
        switch self {
        case .authentError(let description):
            return description
        case .privateKeyError(let description):
            return description
        case .signatureError(let description):
            return description
        }
    }
}

import Foundation
import CommonCrypto
import PromiseKit
import Promises

// swiftlint:disable file_length

enum DocumentRequestError: Error, Equatable {
    case noTitle
    case parserError
}

class DocumentRequest: APIRequest {
    struct DeleteAllDocuments: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    struct DocumentIdParameters: Encodable {
        let id: String
    }

    class UpdateDocument: Codable, Errorable {
        let document: DocumentAPIType?
        var errors: [UserErrorData]?

        init(document: DocumentAPIType?) {
            self.document = document
        }
    }

    class DeleteDocument: UpdateDocument { }

    struct UpdateDocuments: Codable, Errorable {
        let documents: [DocumentAPIType]?
        var errors: [UserErrorData]?
    }

    struct DocumentsParameters: Encodable {
        let updatedAtAfter: Date?
    }

    internal func saveDocumentParameters(_ document: DocumentAPIType) throws -> UpdateDocument {
        try document.encrypt()

        return UpdateDocument(document: DocumentAPIType(document: document))
    }

    internal func saveDocumentsParameters(_ documents: [DocumentAPIType]) throws -> UpdateDocuments {
        let result: [DocumentAPIType] = try documents.map {
            try $0.encrypt()
            return DocumentAPIType(document: $0)
        }

        return UpdateDocuments(documents: result)
    }

    internal func encryptAllNotes(_ notes: [DocumentAPIType]) throws {
        guard Configuration.encryptionEnabled else { return }
        try notes.forEach {
            try $0.encrypt()
            $0.data = $0.encryptedData
        }
    }
}

// MARK: PromiseKit
extension DocumentRequest {
    func fetchDocument(_ documentID: String) -> PromiseKit.Promise<DocumentAPIType> {
        fetchDocumentWithFile("document", documentID)
    }

    func fetchDocumentUpdatedAt(_ documentID: String) -> PromiseKit.Promise<DocumentAPIType> {
       fetchDocumentWithFile("document_updated_at", documentID)
    }

    private func fetchDocumentWithFile(_ filename: String, _ documentID: String) -> PromiseKit.Promise<DocumentAPIType> {
        let parameters = DocumentIdParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: PromiseKit.Promise<FetchDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                        authenticatedCall: true)

        return promise
            .map(on: self.backgroundQueue) { $0 as DocumentAPIType }
            .then(on: self.backgroundQueue) { (documentAPIType: DocumentAPIType) -> PromiseKit.Promise<DocumentAPIType> in
                guard Configuration.encryptionEnabled else {
                    return .value(documentAPIType)
                }

                try documentAPIType.decrypt()
                return .value(documentAPIType)
            }
    }

    func fetchAll(_ updatedAtAfter: Date? = nil) -> PromiseKit.Promise<[DocumentAPIType]> {
        let parameters = DocumentsParameters(updatedAtAfter: updatedAtAfter)

        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: parameters)

        let promise: PromiseKit.Promise<Me> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                             authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) {
            guard let documents = $0.documents else {
                throw DocumentRequestError.parserError
            }

            return documents
        }.then(on: self.backgroundQueue) { (documents: [DocumentAPIType]) -> PromiseKit.Promise<[DocumentAPIType]> in
            guard Configuration.encryptionEnabled else { return .value(documents) }

            try documents.forEach { try $0.decrypt() }

            return .value(documents)
        }
    }

    func save(_ document: DocumentAPIType) -> PromiseKit.Promise<DocumentAPIType> {
        var parameters: UpdateDocument

        do {
            parameters = try saveDocumentParameters(document)
        } catch {
            return Promise(error: error)
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        let promise: PromiseKit.Promise<UpdateDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if let updateDocument = $0.document {
                updateDocument.previousChecksum = document.dataChecksum
                return updateDocument
            }
            throw APIRequestError.parserError
        }
    }

    func deleteAll() -> PromiseKit.Promise<Bool> {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())
        let promise: PromiseKit.Promise<DeleteAllDocuments> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                             authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) {
            guard let success = $0.success else {
                throw DocumentRequestError.parserError
            }
            return success
        }
    }

    func delete(_ id: String) -> PromiseKit.Promise<DocumentAPIType?> {
        let parameters = DocumentIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)
        let promise: PromiseKit.Promise<DeleteDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) { $0.document }
    }

    func saveAll(_ notes: [DocumentAPIType]) -> PromiseKit.Promise<UpdateDocuments> {
        var parameters: UpdateDocuments

        do {
            parameters = try saveDocumentsParameters(notes)
        } catch {
            return Promise(error: error)
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_documents", variables: parameters)

        let promise: PromiseKit.Promise<UpdateDocuments> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                          authenticatedCall: true)
        return promise
    }
}

// MARK: Promises
extension DocumentRequest {
    func fetchDocument(_ documentID: String) -> Promises.Promise<DocumentAPIType> {
        fetchDocumentWithFile("document", documentID)
    }

    func fetchDocumentUpdatedAt(_ documentID: String) -> Promises.Promise<DocumentAPIType> {
       fetchDocumentWithFile("document_updated_at", documentID)
    }

    private func fetchDocumentWithFile(_ filename: String, _ documentID: String) -> Promises.Promise<DocumentAPIType> {
        let parameters = DocumentIdParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: Promises.Promise<FetchDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                      authenticatedCall: true)

        return promise
            .then(on: self.backgroundQueue) { $0 as DocumentAPIType }
            .then(on: self.backgroundQueue) { (documentAPIType: DocumentAPIType) -> Promises.Promise<DocumentAPIType> in
                guard Configuration.encryptionEnabled else {
                    return Promise(documentAPIType)
                }

                try documentAPIType.decrypt()
                return Promise(documentAPIType)
            }
    }

    func fetchAll(_ updatedAtAfter: Date? = nil) -> Promises.Promise<[DocumentAPIType]> {
        let parameters = DocumentsParameters(updatedAtAfter: updatedAtAfter)

        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: parameters)

        let promise: Promises.Promise<Me> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                           authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) {
            guard let documents = $0.documents else {
                throw DocumentRequestError.parserError
            }
            return Promise(documents)
        }.then(on: self.backgroundQueue) { (documents: [DocumentAPIType]) -> Promises.Promise<[DocumentAPIType]> in
            guard Configuration.encryptionEnabled else { return Promises.Promise(documents) }

            try documents.forEach { try $0.decrypt() }

            return Promise(documents)
        }
    }

    func save(_ document: DocumentAPIType) -> Promises.Promise<DocumentAPIType> {
        var parameters: UpdateDocument

        do {
            parameters = try saveDocumentParameters(document)
        } catch {
            return Promise(error)
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        let promise: Promises.Promise<UpdateDocument> = self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                            authenticatedCall: true)

        return promise.then(on: self.backgroundQueue) {
            if let updateDocument = $0.document {
                updateDocument.previousChecksum = document.dataChecksum
                return Promise(updateDocument)
            }
            throw DocumentRequestError.parserError
        }
    }

    func deleteAll() -> Promises.Promise<Bool> {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())
        let promise: Promises.Promise<DeleteAllDocuments> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                           authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) {
            guard let success = $0.success else {
                throw DocumentRequestError.parserError
            }
            return Promise(success)
        }
    }

    func delete(_ id: String) -> Promises.Promise<DocumentAPIType?> {
        let parameters = DocumentIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)
        let promise: Promises.Promise<DeleteDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) { $0.document }
    }

    func saveAll(_ notes: [DocumentAPIType]) -> Promises.Promise<UpdateDocuments> {
        var parameters: UpdateDocuments

        do {
            parameters = try saveDocumentsParameters(notes)
        } catch {
            return Promise(error)
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_documents", variables: parameters)

        let promise: Promises.Promise<UpdateDocuments> = self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                             authenticatedCall: true)
        return promise
    }
}

// MARK: Foundation
extension DocumentRequest {
    @discardableResult
    func saveAll(_ notes: [DocumentAPIType],
                 _ completionHandler: @escaping (Swift.Result<UpdateDocuments, Error>) -> Void) throws -> URLSessionDataTask? {
        var parameters: UpdateDocuments

        do {
            parameters = try saveDocumentsParameters(notes)
        } catch {
            completionHandler(.failure(error))
            return nil
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_documents", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func deleteAll(_ completion: @escaping (Swift.Result<DeleteAllDocuments, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func delete(_ id: String,
                _ completion: @escaping (Swift.Result<DeleteDocument, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = DocumentIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    // return multiple errors, as the API might return more than one.
    func save(_ document: DocumentAPIType,
              _ completion: @escaping (Swift.Result<UpdateDocument, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = try saveDocumentParameters(document)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UpdateDocument, Error>) in
            if case .success(let updateDocument) = result {
                updateDocument.document?.previousChecksum = document.dataChecksum
            }
            completion(result)
        }
    }

    @discardableResult
    func fetchAll(_ updatedAtAfter: Date? = nil,
                  _ completion: @escaping (Swift.Result<[DocumentAPIType], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = DocumentsParameters(updatedAtAfter: updatedAtAfter)

        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<Me, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let me):
                if let documents = me.documents {
                    do {
                        if Configuration.encryptionEnabled {
                            try documents.forEach { try $0.decrypt() }
                        }
                    } catch {
                        // Will catch uncrypting errors
                        completion(.failure(error))
                        return
                    }

                    completion(.success(documents))
                } else {
                    completion(.failure(APIRequestError.parserError))
                }
            }
        }
    }

    @discardableResult
    func fetchDocument(_ documentID: String, _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchDocumentWithFile("document", documentID, completionHandler)
    }

    @discardableResult
    func fetchDocumentUpdatedAt(_ documentID: String, _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchDocumentWithFile("document_updated_at", documentID, completionHandler)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchDocumentWithFile(_ filename: String,
                                       _ documentID: String,
                                       _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = DocumentIdParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<FetchDocument, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let fetchDocument):
                do {
                    try fetchDocument.decrypt()
                } catch {
                    // Will catch uncrypting errors
                    completionHandler(.failure(error))
                    return
                }

                completionHandler(.success(fetchDocument))
            }
        }
    }
}

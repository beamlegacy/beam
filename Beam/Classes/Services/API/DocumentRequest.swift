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
    struct importAllParameters: Encodable {
        let documentsInput: String
    }

    struct ImportDocuments: Decodable, Errorable {
        let notes: [DocumentAPIType]?
        let errors: [UserErrorData]?
    }

    struct DeleteAllDocuments: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    struct DeleteDocumentParameters: Encodable {
        let id: String
    }

    struct DeleteDocument: Decodable, Errorable {
        let document: DocumentAPIType?
        let errors: [UserErrorData]?
    }

    struct UpdateDocumentParameters: Encodable {
        let id: String?
        let title: String
        let data: String?
        let previousChecksum: String?
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct UpdateDocument: Decodable, Errorable {
        let document: DocumentAPIType?
        let errors: [UserErrorData]?
    }

    struct FetchDocumentParameters: Encodable {
        let id: String
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
        let parameters = FetchDocumentParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: PromiseKit.Promise<FetchDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                        authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) { $0 as DocumentAPIType }
    }

    func fetchDocuments() -> PromiseKit.Promise<[DocumentAPIType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: EmptyVariable())

        let promise: PromiseKit.Promise<Me> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                             authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) {
            guard let documents = $0.documents else {
                throw DocumentRequestError.parserError
            }

            return documents
        }
    }

    func saveDocument(_ document: DocumentAPIType) -> PromiseKit.Promise<DocumentAPIType> {
        guard let title = document.title else {
            return Promise(error: DocumentRequestError.noTitle)
        }

        let parameters = UpdateDocumentParameters(id: document.id,
                                                  title: title,
                                                  data: document.data,
                                                  previousChecksum: document.previousChecksum,
                                                  createdAt: document.createdAt,
                                                  updatedAt: document.updatedAt)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        let promise: PromiseKit.Promise<UpdateDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if let document = $0.document {
                return document
            }
            throw APIRequestError.parserError
        }
    }

    func deleteAllDocuments() -> PromiseKit.Promise<Bool> {
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

    func deleteDocument(_ id: String) -> PromiseKit.Promise<DocumentAPIType?> {
        let parameters = DeleteDocumentParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)
        let promise: PromiseKit.Promise<DeleteDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) { $0.document }
    }

    func importDocuments(_ notes: [DocumentAPIType]) -> PromiseKit.Promise<ImportDocuments> {
        let jsonDataEncoded = try? JSONEncoder().encode(notes)
        guard let jsonData = jsonDataEncoded, let jsonString = String(data: jsonData, encoding: .utf8) else {
            return PromiseKit.Promise(error: DocumentRequestError.parserError)
        }

        let variables = importAllParameters(documentsInput: jsonString)

        let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

        let promise: PromiseKit.Promise<ImportDocuments> = performRequest(bodyParamsRequest: bodyParamsRequest,
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
        let parameters = FetchDocumentParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: Promises.Promise<FetchDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                      authenticatedCall: true)

        return promise.then(on: self.backgroundQueue) { $0 as DocumentAPIType }
    }

    func fetchDocuments() -> Promises.Promise<[DocumentAPIType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: EmptyVariable())

        let promise: Promises.Promise<Me> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                           authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) {
            guard let documents = $0.documents else {
                throw DocumentRequestError.parserError
            }
            return Promise(documents)
        }
    }

    func saveDocument(_ document: DocumentAPIType) -> Promises.Promise<DocumentAPIType> {
        guard let title = document.title else {
            return Promises.Promise(DocumentRequestError.noTitle)
        }

        let parameters = UpdateDocumentParameters(id: document.id,
                                                  title: title,
                                                  data: document.data,
                                                  previousChecksum: document.previousChecksum,
                                                  createdAt: document.createdAt,
                                                  updatedAt: document.updatedAt)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        let promise: Promises.Promise<UpdateDocument> = self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                            authenticatedCall: true)

        return promise.then(on: self.backgroundQueue) {
            if let document = $0.document {
                return Promises.Promise(document)
            }
            throw DocumentRequestError.parserError
        }
    }

    func deleteAllDocuments() -> Promises.Promise<Bool> {
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

    func deleteDocument(_ id: String) -> Promises.Promise<DocumentAPIType?> {
        let parameters = DeleteDocumentParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)
        let promise: Promises.Promise<DeleteDocument> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) { $0.document }
    }

    func importDocuments(_ notes: [DocumentAPIType]) -> Promises.Promise<ImportDocuments> {
        let jsonDataEncoded = try? JSONEncoder().encode(notes)
        guard let jsonData = jsonDataEncoded, let jsonString = String(data: jsonData, encoding: .utf8) else {
            return Promises.Promise(DocumentRequestError.parserError)
        }

        let variables = importAllParameters(documentsInput: jsonString)

        let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

        let promise: Promises.Promise<ImportDocuments> = self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                             authenticatedCall: true)
        return promise
    }
}

// MARK: Foundation
extension DocumentRequest {
    @discardableResult
    func importDocuments(_ notes: [DocumentAPIType],
                         _ completionHandler: @escaping (Swift.Result<ImportDocuments, Error>) -> Void) throws -> URLSessionDataTask? {
        var jsonString: String!

        do {
            let jsonData = try JSONEncoder().encode(notes)
            guard let parsedData = String(data: jsonData, encoding: .utf8) else {
                completionHandler(.failure(DocumentRequestError.parserError))
                return nil
            }
            jsonString = parsedData
        } catch {
            completionHandler(.failure(DocumentRequestError.parserError))
            return nil
        }

        let variables = importAllParameters(documentsInput: jsonString)

        let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func deleteAllDocuments(_ completionHandler: @escaping (Swift.Result<DeleteAllDocuments, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func deleteDocument(_ id: String, _ completionHandler: @escaping (Swift.Result<DeleteDocument, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = DeleteDocumentParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    // return multiple errors, as the API might return more than one.
    func saveDocument(_ document: DocumentAPIType, _ completionHandler: @escaping (Swift.Result<UpdateDocument, Error>) -> Void) throws -> URLSessionDataTask {
        guard let title = document.title else {
            throw DocumentRequestError.noTitle
        }
        let parameters = UpdateDocumentParameters(id: document.id,
                                                  title: title,
                                                  data: document.data,
                                                  previousChecksum: document.previousChecksum,
                                                  createdAt: document.createdAt,
                                                  updatedAt: document.updatedAt)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func fetchDocuments(_ completionHandler: @escaping (Swift.Result<[DocumentAPIType], Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<Me, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let me):
                if let documents = me.documents {
                    completionHandler(.success(documents))
                } else {
                    completionHandler(.failure(APIRequestError.parserError))
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
        let parameters = FetchDocumentParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<FetchDocument, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let fetchDocument):
                completionHandler(.success(fetchDocument))
            }
        }
    }
}

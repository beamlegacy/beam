import Foundation
import Alamofire
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

// MARK: Alamofire
extension DocumentRequest {
    /// Sends all documents to the API
    @discardableResult
    func importDocuments(_ notes: [DocumentAPIType],
                         _ completionHandler: @escaping (Swift.Result<ImportDocuments, Error>) -> Void) -> DataRequest? {
        do {
            let jsonData = try JSONEncoder().encode(notes)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                completionHandler(.failure(DocumentRequestError.parserError))
                return nil
            }

            let variables = importAllParameters(documentsInput: jsonString)

            let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

            return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<ImportDocuments>, Error>) in
                switch result {
                case .failure(let error):
                    completionHandler(.failure(error))
                case .success(let parserResult):
                    if let initSession = parserResult.data?.value, initSession.errors?.isEmpty ?? true {
                        completionHandler(.success(initSession))
                    } else {
                        completionHandler(.failure(self.handleError(result: parserResult)))
                    }
                }
            }
        } catch {
            completionHandler(.failure(APIRequestError.parserError))
        }

        return nil
    }

    /// Delete all documents on the server
    @discardableResult
    func deleteAllDocuments(_ completionHandler: @escaping (Swift.Result<Bool, Error>) -> Void) -> DataRequest? {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<DeleteAllDocuments>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let deleteAllDocuments = parserResult.data?.value, deleteAllDocuments.errors?.isEmpty ?? true {
                    completionHandler(.success(true))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    /// Delete document on the server
    @discardableResult
    func deleteDocument(_ id: String, _ completionHandler: @escaping (Swift.Result<Bool, Error>) -> Void) -> DataRequest? {
        let parameters = DeleteDocumentParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<DeleteDocument>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let deleteDocument = parserResult.data?.value, deleteDocument.errors?.isEmpty ?? true {
                    completionHandler(.success(true))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    /// Save document on the server
    @discardableResult
    // return multiple errors, as the API might return more than one.
    func saveDocument(_ document: DocumentAPIType, _ completionHandler: @escaping (Swift.Result<Bool, Error>) -> Void) -> DataRequest? {
        guard let title = document.title else {
            completionHandler(.success(false))
            return nil
        }
        let parameters = UpdateDocumentParameters(id: document.id,
                                                  title: title,
                                                  data: document.data,
                                                  previousChecksum: document.previousChecksum,
                                                  createdAt: document.createdAt,
                                                  updatedAt: document.updatedAt)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<UpdateDocument>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let updateDocument = parserResult.data?.value, updateDocument.errors?.isEmpty ?? true {
                    completionHandler(.success(true))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    /// Fetch all documents from API
    @discardableResult
    func fetchDocuments(_ completionHandler: @escaping (Swift.Result<[DocumentAPIType], Error>) -> Void) -> DataRequest? {
        let bodyParamsRequest = GraphqlParameters(fileName: "documents", variables: EmptyVariable())

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<Me>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let me = parserResult.data?.value, let documents = me.documents {
                    completionHandler(.success(documents))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    /// Fetch document from API
    @discardableResult
    func fetchDocument(_ documentID: String, _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) -> DataRequest? {
        fetchDocumentWithFile("document", documentID, completionHandler)
    }

    /// Fetch document from API
    @discardableResult
    func fetchDocumentUpdatedAt(_ documentID: String, _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) -> DataRequest? {
        fetchDocumentWithFile("document_updated_at", documentID, completionHandler)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchDocumentWithFile(_ filename: String,
                                       _ documentID: String,
                                       _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) -> DataRequest? {
        let parameters = FetchDocumentParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<FetchDocument>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let fetchDocument = parserResult.data?.value {
                    completionHandler(.success(fetchDocument))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
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
        return PromiseKit.Promise { seal in
            guard let title = document.title else {
                seal.reject(DocumentRequestError.noTitle)
                return
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

            promise
                .done(on: self.backgroundQueue) {
                    if let document = $0.document {
                        seal.fulfill(document)
                    } else {
                        seal.reject(DocumentRequestError.parserError)
                    }
                }
                .catch(on: self.backgroundQueue) { seal.reject($0) }
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
        return PromiseKit.Promise { seal in
            do {
                let jsonData = try JSONEncoder().encode(notes)
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    seal.reject(DocumentRequestError.parserError)
                    return
                }

                let variables = importAllParameters(documentsInput: jsonString)

                let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

                let promise: PromiseKit.Promise<ImportDocuments> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                                  authenticatedCall: true)
                promise
                    .done(on: self.backgroundQueue) { seal.fulfill($0) }
                    .catch(on: self.backgroundQueue) { seal.reject($0) }
            } catch {
                seal.reject(error)
            }
        }
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
        return Promises.Promise { fulfill, reject in
            guard let title = document.title else {
                reject(DocumentRequestError.noTitle)
                return
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

            promise
                .then(on: self.backgroundQueue) {
                    if let document = $0.document {
                        fulfill(document)
                    } else {
                        reject(DocumentRequestError.parserError)
                    }
                }
                .catch(on: self.backgroundQueue) { reject($0) }
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
        return Promises.Promise { fulfill, reject in
            do {
                let jsonData = try JSONEncoder().encode(notes)
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    reject(DocumentRequestError.parserError)
                    return
                }

                let variables = importAllParameters(documentsInput: jsonString)

                let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

                let promise: Promises.Promise<ImportDocuments> = self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                                  authenticatedCall: true)
                promise
                    .then(on: self.backgroundQueue) { fulfill($0) }
                    .catch(on: self.backgroundQueue) { reject($0) }
            } catch {
                reject(error)
            }
        }
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
    func deleteAllDocuments(_ completionHandler: @escaping (Swift.Result<DeleteAllDocuments, Error>) -> Void) throws -> URLSessionDataTask? {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func deleteDocument(_ id: String, _ completionHandler: @escaping (Swift.Result<DeleteDocument, Error>) -> Void) throws  -> URLSessionDataTask? {
        let parameters = DeleteDocumentParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    // return multiple errors, as the API might return more than one.
    func saveDocument(_ document: DocumentAPIType, _ completionHandler: @escaping (Swift.Result<UpdateDocument, Error>) -> Void) throws -> URLSessionDataTask? {
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
    func fetchDocuments(_ completionHandler: @escaping (Swift.Result<[DocumentAPIType], Error>) -> Void) throws -> URLSessionDataTask? {
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
    func fetchDocument(_ documentID: String, _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) throws -> URLSessionDataTask? {
        try fetchDocumentWithFile("document", documentID, completionHandler)
    }

    @discardableResult
    func fetchDocumentUpdatedAt(_ documentID: String, _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) throws -> URLSessionDataTask? {
        try fetchDocumentWithFile("document_updated_at", documentID, completionHandler)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchDocumentWithFile(_ filename: String,
                                       _ documentID: String,
                                       _ completionHandler: @escaping (Swift.Result<DocumentAPIType, Error>) -> Void) throws -> URLSessionDataTask? {
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

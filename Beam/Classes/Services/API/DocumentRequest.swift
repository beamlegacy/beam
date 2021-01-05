import Foundation
import Alamofire

class DocumentRequest: APIRequest {
    struct importAllParameters: Encodable {
        let documentsInput: String
    }

    struct ImportDocuments: Decodable, Errorable {
        let notes: [DocumentAPIType]?
        let errors: [UserErrorData]?
    }

    /// Sends all notes to the API
    @discardableResult
    func importDocuments(_ notes: [DocumentAPIType],
                         _ completionHandler: @escaping (Result<ImportDocuments, Error>) -> Void) -> DataRequest? {
        do {
            let jsonData = try JSONEncoder().encode(notes)
            let jsonString = String(data: jsonData, encoding: .utf8)!

            let variables = importAllParameters(documentsInput: jsonString)

            let bodyParamsRequest = GraphqlParameters(fileName: "import_documents", variables: variables)

            return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<ImportDocuments>, Error>) in
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

    struct DeleteAllDocuments: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    /// Delete all notes on the server
    @discardableResult
    func deleteAllDocuments(_ completionHandler: @escaping (Result<Bool, Error>) -> Void) -> DataRequest? {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_documents", variables: EmptyVariable())

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<DeleteAllDocuments>, Error>) in
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

    struct DeleteDocumentParameters: Encodable {
        let id: String
    }

    struct DeleteDocument: Decodable, Errorable {
        let document: DocumentAPIType?
        let errors: [UserErrorData]?
    }

    /// Delete document on the server
    @discardableResult
    func deleteDocument(_ id: String, _ completionHandler: @escaping (Result<Bool, Error>) -> Void) -> DataRequest? {
        let parameters = DeleteDocumentParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_document", variables: parameters)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<DeleteDocument>, Error>) in
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

    struct UpdateDocumentParameters: Encodable {
        let id: String?
        let title: String
        var data: String?
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct UpdateDocument: Decodable, Errorable {
        let document: DocumentAPIType?
        let errors: [UserErrorData]?
    }

    /// Save document on the server
    @discardableResult
    func saveDocument(_ document: DocumentAPIType, _ completionHandler: @escaping (Result<Bool, Error>) -> Void) -> DataRequest? {
        guard let title = document.title else {
            completionHandler(.success(false))
            return nil
        }
        let parameters = UpdateDocumentParameters(id: document.id,
                                                  title: title,
                                                  data: document.data,
                                                  createdAt: document.createdAt,
                                                  updatedAt: document.updatedAt)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_document", variables: parameters)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<UpdateDocument>, Error>) in
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

    struct FetchDocumentParameters: Encodable {
        let id: String
    }
    struct FetchDocument: Decodable, Errorable {
        let document: DocumentAPIType?
        let errors: [UserErrorData]?
    }
    /// Save bullet on the server
    @discardableResult
    func fetchDocument(_ documentID: String, _ completionHandler: @escaping (Result<DocumentAPIType, Error>) -> Void) -> DataRequest? {
        let parameters = FetchDocumentParameters(id: documentID)
        let bodyParamsRequest = GraphqlParameters(fileName: "document", variables: parameters)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<FetchDocument>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let data = parserResult.data?.value, let document = data.document {
                    completionHandler(.success(document))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }
}

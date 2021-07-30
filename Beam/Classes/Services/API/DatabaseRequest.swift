import Foundation
import PromiseKit
import Promises
import BeamCore

enum DatabaseRequestError: Error, Equatable {
    case noTitle
    case parserError
}
class DatabaseRequest: APIRequest {
    // MARK: delete
    struct DatabaseIdParameters: Encodable {
        let id: String
    }

    struct DeleteAllDatabases: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    // MARK: updates
    class UpdateDatabase: Codable, Errorable {
        let database: DatabaseAPIType?
        var errors: [UserErrorData]?

        init(database: DatabaseAPIType?) {
            self.database = database
        }
    }

    class DeleteDatabase: UpdateDatabase { }

    class FetchDatabase: DatabaseAPIType, Errorable, APIResponseCodingKeyProtocol {
        static let codingKey = "database"
        let errors: [UserErrorData]? = nil
    }

    struct UpdateDatabases: Codable, Errorable {
        let databases: [DatabaseAPIType]?
        var errors: [UserErrorData]?
    }

    struct DatabasesParameters: Encodable {
        let updatedAtAfter: Date?
    }
}

// MARK: -
// MARK: Foundation
extension DatabaseRequest {
    @discardableResult
    func delete(_ id: String,
                _ completionHandler: @escaping (Swift.Result<DeleteDatabase, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = DatabaseIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_database", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func deleteAll(_ completion: @escaping (Swift.Result<DeleteAllDatabases, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_databases", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    // return multiple errors, as the API might return more than one.
    func save(_ database: DatabaseAPIType,
              _ completion: @escaping (Swift.Result<UpdateDatabase, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "update_database",
                                                  variables: UpdateDatabase(database: database))

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func saveAll(_ databases: [DatabaseAPIType],
                 _ completion: @escaping (Swift.Result<UpdateDatabases, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "update_databases",
                                                  variables: UpdateDatabases(databases: databases))

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func fetchAll(_ updatedAtAfter: Date? = nil,
                  _ completion: @escaping (Swift.Result<[DatabaseAPIType], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = DatabasesParameters(updatedAtAfter: updatedAtAfter)
        let bodyParamsRequest = GraphqlParameters(fileName: "databases", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UserMe, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let me):
                if let databases = me.databases {
                    completion(.success(databases))
                } else {
                    completion(.failure(APIRequestError.parserError))
                }
            }
        }
    }

    @discardableResult
    func fetchDatabase(_ id: UUID,
                       _ completion: @escaping (Swift.Result<DatabaseAPIType, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = DatabaseIdParameters(id: id.uuidString.lowercased())
        let bodyParamsRequest = GraphqlParameters(fileName: "database", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<FetchDatabase, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let fetchDatabase):
                completion(.success(fetchDatabase))
            }
        }
    }

    func save(_ databases: [DatabaseAPIType]) throws -> Bool {
        let group = DispatchGroup()
        var errors: [Error] = []

        for database in databases {
            group.enter()

            try saveDatabaseAndManageTitleConflict(database) { (error: Error?) in
                if let error = error { errors.append(error) }

                group.leave()
            }
        }

        group.wait()

        return errors.isEmpty
    }

    private func saveDatabaseAndManageTitleConflict(_ database: DatabaseAPIType,
                                                    _ completion: @escaping (Error?) -> Void) throws {

        try save(database) { result in
            switch result {
            case .failure(let error):
                // TODO: Add a `titleConflict` error for easier management
                if case APIRequestError.apiError(let explanations) = error,
                   explanations == ["Title has already been taken"] {
                    var title = database.title ?? "no title"
                    title += " \(BeamDate.now)"

                    Logger.shared.logInfo("Can't save database \(database.title ?? ""), will retry with \(title)",
                                          category: .database)

                    database.title = title

                    do {
                        try self.saveDatabaseAndManageTitleConflict(database, completion)
                    } catch {
                        completion(error)
                    }
                    return
                } else {
                    completion(error)
                }
                Logger.shared.logError(error.localizedDescription, category: .database)
            case .success:
                completion(nil)
            }
        }
    }
}

// MARK: -
// MARK: PromiseKit
extension DatabaseRequest {
    func delete(_ id: String) -> PromiseKit.Promise<DatabaseAPIType?> {
        let parameters = DatabaseIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_database", variables: parameters)
        let promise: PromiseKit.Promise<DeleteDatabase> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) { $0.database }
    }

    func deleteAll() -> PromiseKit.Promise<Bool> {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_databases", variables: EmptyVariable())

        let promise: PromiseKit.Promise<DeleteAllDatabases> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                             authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) {
            guard let success = $0.success else {
                throw DocumentRequestError.parserError
            }
            return success
        }
    }

    // return multiple errors, as the API might return more than one.
    func save(_ database: DatabaseAPIType) -> PromiseKit.Promise<DatabaseAPIType> {
        let bodyParamsRequest = GraphqlParameters(fileName: "update_database",
                                                  variables: UpdateDatabase(database: database))

        let promise: PromiseKit.Promise<UpdateDatabase> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if let updateDatabase = $0.database {
                return updateDatabase
            }
            throw APIRequestError.parserError
        }
    }

    func saveAll(_ databases: [DatabaseAPIType]) -> PromiseKit.Promise<[DatabaseAPIType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "update_databases",
                                                  variables: UpdateDatabases(databases: databases))

        let promise: PromiseKit.Promise<UpdateDatabases> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                          authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if let updateDatabases = $0.databases {
                return updateDatabases
            }
            throw APIRequestError.parserError
        }
    }

    func fetchAll(_ updatedAtAfter: Date? = nil) -> PromiseKit.Promise<[DatabaseAPIType]> {
        let parameters = DatabasesParameters(updatedAtAfter: updatedAtAfter)
        let bodyParamsRequest = GraphqlParameters(fileName: "databases", variables: parameters)

        let promise: PromiseKit.Promise<UserMe> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                             authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) {
            guard let databases = $0.databases else {
                throw DocumentRequestError.parserError
            }

            return databases
        }
    }
}

// MARK: -
// MARK: Promises
extension DatabaseRequest {
    func delete(_ id: String) -> Promises.Promise<DatabaseAPIType?> {
        let parameters = DatabaseIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_database", variables: parameters)
        let promise: Promises.Promise<DeleteDatabase> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) { $0.database }
    }

    func deleteAll() -> Promises.Promise<Bool> {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_databases", variables: EmptyVariable())

        let promise: Promises.Promise<DeleteAllDatabases> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                          authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) {
            guard let success = $0.success else {
                throw DocumentRequestError.parserError
            }
            return Promise(success)
        }
    }

    // return multiple errors, as the API might return more than one.
    func save(_ database: DatabaseAPIType) -> Promises.Promise<DatabaseAPIType> {
        let bodyParamsRequest = GraphqlParameters(fileName: "update_database",
                                                  variables: UpdateDatabase(database: database))

        let promise: Promises.Promise<UpdateDatabase> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: true)

        return promise.then(on: self.backgroundQueue) {
            if let updateDatabase = $0.database {
                return Promise(updateDatabase)
            }
            throw APIRequestError.parserError
        }
    }

    func saveAll(_ databases: [DatabaseAPIType]) -> Promises.Promise<[DatabaseAPIType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "update_databases",
                                                  variables: UpdateDatabases(databases: databases))

        let promise: Promises.Promise<UpdateDatabases> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                          authenticatedCall: true)

        return promise.then(on: self.backgroundQueue) {
            if let updateDatabases = $0.databases {
                return Promise(updateDatabases)
            }
            throw APIRequestError.parserError
        }
    }

    func fetchAll(_ updatedAtAfter: Date? = nil) -> Promises.Promise<[DatabaseAPIType]> {
        let parameters = DatabasesParameters(updatedAtAfter: updatedAtAfter)
        let bodyParamsRequest = GraphqlParameters(fileName: "databases", variables: parameters)

        let promise: Promises.Promise<UserMe> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                           authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) {
            guard let databases = $0.databases else {
                throw DocumentRequestError.parserError
            }

            return Promise(databases)
        }
    }
}

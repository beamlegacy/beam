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
    struct DeleteDatabaseParameters: Encodable {
        let id: String
    }

    struct DeleteDatabase: Decodable, Errorable {
        let database: DatabaseAPIType?
        let errors: [UserErrorData]?
    }

    struct DeleteAllDatabases: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    // MARK: updates
    struct UpdateDatabaseParameters: Encodable {
        let id: String?
        let title: String
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct UpdateDatabase: Decodable, Errorable {
        let database: DatabaseAPIType?
        let errors: [UserErrorData]?
    }

    internal func saveDatabaseParameters(_ database: DatabaseAPIType) throws -> UpdateDatabaseParameters {
        guard let title = database.title else {
            throw DatabaseRequestError.noTitle
        }

        let parameters = UpdateDatabaseParameters(id: database.id,
                                                  title: title,
                                                  createdAt: database.createdAt,
                                                  updatedAt: database.updatedAt)

        return parameters
    }
}

// MARK: -
// MARK: Foundation
extension DatabaseRequest {
    @discardableResult
    func delete(_ id: String, _ completionHandler: @escaping (Swift.Result<DeleteDatabase, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = DeleteDatabaseParameters(id: id)
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
        let parameters = try saveDatabaseParameters(database)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_database", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func fetchAll(_ completion: @escaping (Swift.Result<[DatabaseAPIType], Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "databases", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<Me, Error>) in
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
        let parameters = DeleteDatabaseParameters(id: id)
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
        var parameters: UpdateDatabaseParameters
        do {
            parameters = try saveDatabaseParameters(database)
        } catch {
            return Promise(error: error)
        }
        let bodyParamsRequest = GraphqlParameters(fileName: "update_database", variables: parameters)

        let promise: PromiseKit.Promise<UpdateDatabase> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if let updateDatabase = $0.database {
                return updateDatabase
            }
            throw APIRequestError.parserError
        }
    }

    func fetchAll() -> PromiseKit.Promise<[DatabaseAPIType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "databases", variables: EmptyVariable())

        let promise: PromiseKit.Promise<Me> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                             authenticatedCall: true)
        return promise.map(on: self.backgroundQueue) {
            guard let databases = $0.databases else {
                throw DocumentRequestError.parserError
            }

            return databases
        }
    }

    func save(_ databases: [DatabaseAPIType]) -> PromiseKit.Promise<[DatabaseAPIType]> {
        let promises: [PromiseKit.Promise<DatabaseAPIType>] = databases.map {
            save($0)
        }

        return firstly {
            when(fulfilled: promises)
        }
    }
}

// MARK: -
// MARK: Promises
extension DatabaseRequest {
    func delete(_ id: String) -> Promises.Promise<DatabaseAPIType?> {
        let parameters = DeleteDatabaseParameters(id: id)
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
        var parameters: UpdateDatabaseParameters
        do {
            parameters = try saveDatabaseParameters(database)
        } catch {
            return Promise(error)
        }
        let bodyParamsRequest = GraphqlParameters(fileName: "update_database", variables: parameters)

        let promise: Promises.Promise<UpdateDatabase> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: true)

        return promise.then(on: self.backgroundQueue) {
            if let updateDatabase = $0.database {
                return Promise(updateDatabase)
            }
            throw APIRequestError.parserError
        }
    }

    func fetchAll() -> Promises.Promise<[DatabaseAPIType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "databases", variables: EmptyVariable())

        let promise: Promises.Promise<Me> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                           authenticatedCall: true)
        return promise.then(on: self.backgroundQueue) {
            guard let databases = $0.databases else {
                throw DocumentRequestError.parserError
            }

            return Promise(databases)
        }
    }

    func save(_ databases: [DatabaseAPIType]) -> Promises.Promise<[DatabaseAPIType]> {
        let promises: [Promises.Promise<DatabaseAPIType>] = databases.map {
            save($0)
        }

        return Promises.all(promises)
    }
}

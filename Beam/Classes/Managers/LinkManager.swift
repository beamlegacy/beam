//
//  LinkManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/01/2021.
//

import Foundation
import CoreData
import BeamCore

class LinkManager: LinkManagerBase {

    var coreDataManager: CoreDataManager
    let mainContext: NSManagedObjectContext

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        self.mainContext = self.coreDataManager.mainContext
    }

    func saveLink(_ linkStruct: LinkStruct, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(linkStruct.url)", category: .coredata)
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let link = StoredLink.fetchWithId(context, linkStruct.bid) ?? StoredLink(context: context)

            link.bid = linkStruct.bid
            link.url = linkStruct.url
            link.title = linkStruct.title

            do {
                try CoreDataManager.save(context)
                Logger.shared.logDebug("saveLink CoreDataManager saved", category: .coredata)
            } catch {
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
                completion?(.failure(error))
                return
            }

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                completion?(.success(true))
                return
            }

            // If authenticated
//            self.linkRequest.saveLink(linkStruct.asApiType()) { result in
//                switch result {
//                case .failure(let error):
//                    completion?(.failure(error))
//                case .success:
//                    completion?(.success(true))
//                }
//            }
        }
    }

    func loadLinkById(id: UInt64) -> LinkStruct? {
        guard let link = StoredLink.fetchWithId(mainContext, Int64(bitPattern: id)) else { return nil }

        return parseLinkBody(link)
    }

    func loadLinkByTitle(title: String) -> LinkStruct? {
        guard let link = StoredLink.fetchWithTitle(mainContext, title) else { return nil }

        return parseLinkBody(link)
    }

    func documentsWithTitleMatch(title: String) -> [LinkStruct] {
        return StoredLink.fetchAllWithTitleMatch(mainContext, title).compactMap { link -> LinkStruct? in
            parseLinkBody(link)
        }
    }

    func loadAllLinksWithLimit(_ limit: Int = 4) -> [LinkStruct] {
        return StoredLink.fetchAllWithLimitResult(mainContext, limit).compactMap { link -> LinkStruct? in
            parseLinkBody(link)
        }
    }

    func loadLinks() -> [LinkStruct] {
        return StoredLink.fetchAll(context: mainContext).compactMap { link in
            parseLinkBody(link)
        }
    }

    private func parseLinkBody(_ link: StoredLink) -> LinkStruct? {
        return LinkStruct(bid: link.bid,
                              url: link.url,
                              title: link.title)
    }

    func deleteLink(id: UInt64, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let link = StoredLink.fetchWithId(context, Int64(bitPattern: id))
            link?.delete(context)

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                completion?(.success(true))
                return
            }

            // If authenticated
//            self.linkRequest.deleteDocument(id.uuidString.lowercased()) { result in
//                switch result {
//                case .failure(let error):
//                    completion?(.failure(error))
//                case .success:
//                    completion?(.success(true))
//                }
//            }
        }
    }

    func deleteAllLinks() {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            _ = StoredLink.deleteForPredicate(NSPredicate(value: true), context)
        }
    }

//    func uploadAll(_ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) {
//        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
//            let documents = Document.fetchAll(context: context)
//            let documentsArray: [DocumentAPIType] = documents.map { document in document.asApiType() }
//
//            self.documentRequest.importDocuments(documentsArray) { result in
//                switch result {
//                case .failure(let error):
//                    Logger.shared.logError(error.localizedDescription, category: .network)
//                    completionHandler?(.failure(error))
//                case .success:
//                    Logger.shared.logDebug("Documents imported", category: .network)
//                    completionHandler?(.success(true))
//                }
//            }
//        }
//    }
}

//
//  AutocompleteManager+Publishers.swift
//  Beam
//
//  Created by Remi Santos on 16/07/2021.
//

import Foundation
import Combine
import BeamCore

extension AutocompleteManager {
    typealias AutocompletePublisherSourceResults = (source: AutocompleteResult.Source, results: [AutocompleteResult])

    func getAutocompletePublishers(for searchText: String) -> [AnyPublisher<AutocompletePublisherSourceResults, Never>] {
        [
            futureToPublisher(autocompleteNotesResults(for: searchText), source: .note),
            futureToPublisher(autocompleteNotesContentsResults(for: searchText), source: .note),
            futureToPublisher(autocompleteTopDomainResults(for: searchText), source: .topDomain),
            futureToPublisher(autocompleteHistoryResults(for: searchText), source: .history),
            futureToPublisher(autocompleteLinkStoreResults(for: searchText), source: .url),
            self.autocompleteCanCreateNoteResult(for: searchText)
                .replaceError(with: false)
                .map { canCreate in
                    let createResult = AutocompleteResult(text: searchText,
                                                          source: .createCard,
                                                          information: "New card",
                                                          completingText: searchText)
                    let results = canCreate ? [createResult] : []
                    return (AutocompleteResult.Source.createCard, results)
                }.eraseToAnyPublisher()
        ]
    }
    private func futureToPublisher(_ future: Future<[AutocompleteResult], Error>,
                                   source: AutocompleteResult.Source) -> AnyPublisher<AutocompletePublisherSourceResults, Never> {
        future
            .catch { error -> AnyPublisher<[AutocompleteResult], Never> in
                // catch the error while not stopping the publisher chain
                Logger.shared.logError(error.localizedDescription, category: .autocompleteManager)
                return Just([]).eraseToAnyPublisher()
            }
            .map { someResults in
                return (source, someResults)
            }
            .eraseToAnyPublisher()
    }

    private func autocompleteNotesResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            self.beamData.documentManager.documentsWithLimitTitleMatch(title: query, limit: 6) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let documentStructs):
                    let autocompleteResults = documentStructs.map {
                        AutocompleteResult(text: $0.title, source: .note, completingText: query, uuid: $0.id)
                    }
                    promise(.success(autocompleteResults))
                }
            }
        }
    }

    private func autocompleteNotesContentsResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { [weak beamData] promise in
            GRDBDatabase.shared.search(matchingAllTokensIn: query, maxResults: 10) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let notesContentResults):
                    // TODO: get all titles and make a single CoreData request for all titles
                    let autocompleteResults = notesContentResults.compactMap { result -> AutocompleteResult? in
                        // Check if the note still exists before proceeding.
                        guard beamData?.documentManager.loadDocumentById(id: result.noteId) != nil else { return nil }
                        return AutocompleteResult(text: result.title,
                                                  source: .note,
                                                  completingText: query,
                                                  uuid: result.uid)
                    }
                    promise(.success(autocompleteResults))
                }
            }
        }
    }

    private func autocompleteHistoryResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            GRDBDatabase.shared.searchHistory(query: query, enabledFrecencyParam: .readingTime30d0) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let historyResults):
                    let autocompleteResults = historyResults.map { result -> AutocompleteResult in
                        var urlString = result.url
                        let url = URL(string: urlString)
                        if let url = url {
                            urlString = url.urlStringWithoutScheme
                        }
                        return AutocompleteResult(text: result.title, source: .history, url: url, information: urlString, completingText: query)
                    }
                    promise(.success(autocompleteResults))
                }
            }
        }
    }

    private func autocompleteLinkStoreResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let results = LinkStore.shared.getLinks(matchingUrl: query).map { result -> AutocompleteResult in
                let url = URL(string: result.url)
                return AutocompleteResult(text: result.url,
                                          source: .url,
                                          url: url,
                                          information: result.title,
                                          completingText: query)
            }
            promise(.success(results))
        }
    }

    private func autocompleteCanCreateNoteResult(for query: String) -> Future<Bool, Error> {
        Future { promise in
            self.beamData.documentManager.loadDocumentByTitle(title: query) { result in
                switch result {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let documentStruct):
                    let canCreateNote = documentStruct == nil && URL(string: query)?.scheme == nil
                    promise(.success(canCreateNote))
                }
            }
        }
    }

    private func autocompleteTopDomainResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            TopDomainDatabase.shared.search(withPrefix: query) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let topDomain):
                    guard let url = URL(string: topDomain.url) else {
                        promise(.failure(TopDomainDatabaseError.notFound))
                        return
                    }
                    let ac = AutocompleteResult(text: url.absoluteString,
                                                source: .topDomain,
                                                url: url,
                                                information: "top domain",
                                                completingText: query)

                    promise(.success([ac]))
                }
            }
        }
    }

}

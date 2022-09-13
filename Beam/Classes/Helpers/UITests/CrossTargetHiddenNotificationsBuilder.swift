//
//  CrossTargetHiddenNotificationsBuilder.swift
//  Beam
//
//  Created by Remi Santos on 01/09/2022.
//

import Foundation
import Combine
import BeamCore

/// Register hidden identifier to be called by the cross target beeper
/// Also can support dynamic identifier updated at runtime.
class CrossTargetHiddenNotificationsBuilder {

    weak private var data: BeamData?
    private var scope = Set<AnyCancellable>()
    private var registeredIdentifiers = [String]()
    private var beeper: CrossTargetBeeper
    init(data: BeamData?, beeper: CrossTargetBeeper) {
        self.beeper = beeper
        self.data = data
        setupDocumentsObservers()
        registerDynamicIdentifiers()
    }

    private func setupDocumentsObservers() {
        let handler: (BeamDocument) -> Void = { [weak self] _ in
            self?.registerDynamicIdentifiers()
        }
        BeamDocumentCollection.documentSaved
            .removeDuplicates(by: { old, new in
                old.title == new.title
            })
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: handler)
            .store(in: &scope)

        BeamDocumentCollection.documentDeleted
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink(receiveValue: handler)
            .store(in: &scope)
    }

    private func registerDynamicIdentifiers() {
        registeredIdentifiers.forEach { beeper.unregister(identifier: $0) }
        registeredIdentifiers.removeAll()

        let handlerForId: (String) -> BeepHandler = { [weak self] identifier in
            { self?.handle(identifier: identifier) }
        }
        registeredIdentifiers = UITestsHiddenMenuAvailableCommands.allCases.map { $0.rawValue } + allNotesRelatedIdentifiers()
        registeredIdentifiers.forEach { identifier in
            beeper.register(identifier: identifier, handler: handlerForId(identifier))
        }
    }

    private func allNotesRelatedIdentifiers() -> [String] {
        var identifiers: [String] = []
        try? data?.currentDocumentCollection?.fetch().forEach { doc in
            identifiers.append(UITestsHiddenMenuAvailableCommands.openNoteIdentifier(title: doc.title))
        }
        return identifiers
    }

    private func handle(identifier: String) {
        if let hiddenId = UITestsHiddenMenuAvailableCommands(rawValue: identifier) {
            switch hiddenId {
            case .openTodayNote:
                openNote(journalDate: BeamDate.now)
            case .deleteAllNotes:
                deleteAllNotes()
            default: break
            }
            return
        }
        if identifier.starts(with: UITestsHiddenMenuAvailableCommands.openNotePrefix.rawValue) {
            let noteTitle = String(identifier[UITestsHiddenMenuAvailableCommands.openNotePrefix.rawValue.endIndex...])
            openNote(title: noteTitle)
        }
    }

    private func openNote(title: String? = nil, journalDate: Date? = nil) {
        if let title = title, let note = BeamNote.fetch(title: title) {
            open(note: note)
        } else if let journalDate = journalDate, let note = BeamNote.fetch(journalDate: journalDate) {
            open(note: note)
        }
    }

    private func open(note: BeamNote) {
        AppDelegate.main.window?.state.navigateToNote(note)
    }
    
    private func deleteAllNotes() {
        guard let collection = data?.currentDocumentCollection else { return }
        let cmdManager = CommandManagerAsync<BeamDocumentCollection>()
        cmdManager.deleteAllDocuments(in: collection)
    }

}

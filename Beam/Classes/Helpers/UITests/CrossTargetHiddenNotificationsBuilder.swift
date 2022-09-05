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
        data?.currentDocumentCollection?.observeIds([.userFacingNotes], nil).sink { _ in } receiveValue: { [weak self] _ in
            self?.registerDynamicIdentifiers()
        }.store(in: &scope)

        registerDynamicIdentifiers()
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

}

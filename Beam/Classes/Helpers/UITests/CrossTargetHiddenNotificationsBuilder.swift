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
            case .resizeAndCenterAppE2E:
                resizeAndCenterAppForE2ETests()
            case .tabGroupCaptured:
                createTabGroupsCaptured(count: 1)
            case .tabGroupCapturedNamed:
                createTabGroupsCaptured(named: true, count: 1)
            case .tabGroupCapturedAndShared:
                createTabGroupsCaptured(count: 1, shared: true)
            case .tabGroupCapturedNamedAndShared:
                createTabGroupsCaptured(named: true, count: 1, shared: true)
            case .tabGroupsCaptured:
                createTabGroupsCaptured(count: 4)
            case .tabGroupsCapturedNamed:
                createTabGroupsCaptured(named: true, count: 4)
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
    
    private func resizeAndCenterAppForE2ETests() {
        AppDelegate.main.resizeWindow(width: 1500, height: 1000)
        AppDelegate.main.window?.center()
    }

    private func urlForTestPage(identifier: String) -> URL? {
        Bundle.main.url(forResource: "UITests-\(identifier)",
                        withExtension: "html", subdirectory: nil)
    }
    private func titleForTestPage(identifier: String) -> String? {
        [
            "1": "Point And Shoot Test Fixture Ultralight Beam",
            "2": "Point And Shoot Test Fixture I-Beam",
            "3": "Point And Shoot Test Fixture Cursor",
            "4": "Point And Shoot Test Fixture Background image"
        ][identifier]
    }

    func createTabGroupsCaptured(named: Bool = false, count: Int = 1, shared: Bool = false) {
        Task { @MainActor in
            let tabGroupingManager = data?.tabGroupingManager
            guard let note = try? BeamNote.fetchOrCreate(BeamUITestsMenuGeneratorSource(), title: "Note With Tab Groups") else { return }
            note.addChild(BeamElement("Content"))
            for i in 0..<count {
                let pages = ["1", "2", "3", "4"]
                let links: [Link] = pages.compactMap {
                    guard let url = urlForTestPage(identifier: $0) else { return nil }
                    return LinkStore.shared.visit(url.absoluteString, title: titleForTestPage(identifier: $0), content: nil)
                }
                let group = TabGroup(pageIds: links.map({ $0.id }), title: named ? "Test\(i+1)" : nil,
                                     color: .init(TabGroupingColor(designColor: TabGroupingColor.DesignColor.allCases.randomElement())),
                                     isLocked: true, parentGroup: nil)
                let groupObject = TabGroupingStoreManager.convertGroupToBeamObject(group, pages: links.map {
                    .init(id: $0.id, url: URL(string: $0.url)!, title: $0.title ?? "")
                })
                data?.tabGroupingDBManager?.save(groups: [groupObject])
                _ = await tabGroupingManager?.addGroup(group, toNote: note)

                if shared {
                    guard let capturedGroupObject = data?.tabGroupingDBManager?.fetch(copiesOfGroup: group.id).first,
                          let state = AppDelegate.main.window?.state else {
                        fatalError("Group was not copied to insert into note?")
                    }
                    let capturedGroup = TabGroupingStoreManager.convertBeamObjectToGroup(capturedGroupObject)
                    // Calling shareGroup with a timeout of 10s using task groups
                    _ = try await withThrowingTaskGroup(of: Bool.self) { group -> Bool in
                        group.addTask {
                            await withUnsafeContinuation { continuation in
                                tabGroupingManager?.shareGroup(capturedGroup, state: state, completion: { _ in
                                    continuation.resume(returning: true)
                                })
                            }
                        }
                        group.addTask {
                            try await Task.sleep(nanoseconds: 10_000_000_000) // 10s
                            throw CancellationError()
                        }

                        guard let value = try await group.next() else {
                            return false
                        }

                        group.cancelAll()
                        return value
                    }
                }
            }
            AppDelegate.main.window?.state.navigateToNote(note)
        }
    }

}

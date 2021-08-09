//
//  AllCardsPageContentView.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2021.
//

import SwiftUI
import BeamCore
import Combine

class AllCardsViewModel: ObservableObject {

    fileprivate var data: BeamData?
    @Published fileprivate var allNotes = [DocumentStruct]() {
        didSet {
            updateNoteItemsFromAllNotes()
        }
    }
    @Published fileprivate var allNotesItems = [NoteTableViewItem]()
    @Published fileprivate var privateNotesItems = [NoteTableViewItem]()
    @Published fileprivate var publicNotesItems = [NoteTableViewItem]()
    @Published fileprivate var shouldReloadData: Bool? = false

    private var coreDataObservers = Set<AnyCancellable>()
    private var metadataFetchers = Set<AnyCancellable>()
    private var notesMetadataCache: NoteListMetadataCache {
        NoteListMetadataCache.shared
    }

    init() {
        CoreDataContextObserver.shared
            .publisher(for: .anyDocumentChange)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAllNotes()
            }
            .store(in: &coreDataObservers)
    }

    fileprivate func refreshAllNotes() {
        guard let documentManager = data?.documentManager else { return }
        allNotes = documentManager.loadAll()
    }

    private func updateNoteItemsFromAllNotes() {
        allNotesItems = allNotes.compactMap { doc in
            let note = BeamNote.getFetchedNote(doc.id)
            let item = NoteTableViewItem(document: doc, note: note)
            if let metadata = notesMetadataCache.metadata(for: item.id) {
                item.mentions = metadata.mentions
                if item.words < 0 {
                    item.words = metadata.wordsCount
                }
            }
            return item
        }
        updatePublicPrivateLists()
        asyncComputeNotesMetadata(notesItems: allNotesItems)
    }

    private func updatePublicPrivateLists() {
        publicNotesItems = allNotesItems.filter({ $0.isPublic })
        privateNotesItems = allNotesItems.filter({ !$0.isPublic })
    }

    private func updateMetadatasForItems(with fetchedNotes: [UUID: BeamNote]) {
        var shouldReload = false
        allNotesItems = allNotesItems.map { item in
            if let metadata = notesMetadataCache.metadata(for: item.id), let note = fetchedNotes[item.id] {
                item.mentions = metadata.mentions
                item.words = metadata.wordsCount
                item.note = note
                shouldReload = true
            }
            return item
        }
        updatePublicPrivateLists()
        shouldReloadData = shouldReload
    }

    private func asyncComputeNotesMetadata(notesItems: [NoteTableViewItem]) {
        guard let documentManager = data?.documentManager else { return }
        metadataFetchers.removeAll()
        fetchAllNotesMetadata(for: notesItems, documentManager: documentManager)
            .receive(on: DispatchQueue.main)
            .sink { fetchedNotes in
                self.updateMetadatasForItems(with: fetchedNotes)
            }
            .store(in: &metadataFetchers)
    }

    private func fetchAllNotesMetadata(for notesItems: [NoteTableViewItem], documentManager: DocumentManager) -> AnyPublisher<[UUID: BeamNote], Never> {
        Future { promise in
            var metadatas = [UUID: NoteListMetadata]()
            var fetchedNotes = [UUID: BeamNote]()
            DispatchQueue.global(qos: .userInteractive).async {
                notesItems.forEach { item in
                    guard item.note == nil || item.mentions < 0 else { return }
                    guard let note = item.note ?? item.note(withDocumentManager: documentManager) else { return }
                    let mentions = note.linksAndReferences(with: documentManager, fast: true).count
                    let metadata = NoteListMetadata(mentions: mentions, wordsCount: note.textStats.wordsCount)
                    metadatas[item.id] = metadata
                    fetchedNotes[item.id] = note
                }
                DispatchQueue.main.async {
                    metadatas.forEach { key, value in
                        NoteListMetadataCache.shared.saveMetadata(value, for: key)
                    }
                    promise(.success(fetchedNotes))
                }
            }
        }.eraseToAnyPublisher()
    }
}

extension AllCardsViewModel: AllCardsContextualMenuDelegate {
    func contextualMenuWillDeleteDocuments(ids: [UUID], all: Bool) {
        if all {
            allNotes.removeAll()
        } else {
            allNotes.removeAll { ids.contains($0.id) }
        }
    }
}

struct AllCardsPageContentView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var data: BeamData
    @Environment(\.undoManager) var undoManager

    private var currentNotesList: [NoteTableViewItem] {
        switch listType {
        case .publicNotes:
            return model.publicNotesItems
        case .privateNotes:
            return model.privateNotesItems
        default:
            return model.allNotesItems
        }
    }

    @ObservedObject private var model = AllCardsViewModel()
    @State private var selectedRowsIndexes = IndexSet()
    @State private var hoveredRowIndex: Int?
    @State private var hoveredRowFrame: NSRect?

    private static var dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt
    }()

    static private func loadingIntValueString(_ value: Any?) -> String {
        guard let intValue = value as? Int else { return "" }
        return intValue >= 0 ? "\(intValue)" : "--"
    }

    private var columns = [
        TableViewColumn(key: "checkbox", title: "", type: TableViewColumn.ColumnType.CheckBox,
                        sortable: false, resizable: false, width: 16),
        TableViewColumn(key: "title", title: "Title", editable: true,
                        isLink: true, sortableDefaultAscending: true, width: 200),
        TableViewColumn(key: "words", title: "Words", width: 50, stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: "mentions", title: "Mentions", width: 70, stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: "createdAt", title: "Created", stringFromKeyValue: { value in
            if let date = value as? Date {
                return AllCardsPageContentView.dateFormatter.string(from: date)
            }
            return ""
        }),
        TableViewColumn(key: "updatedAt",
                        title: "Updated",
                        isInitialSortDescriptor: true,
                        stringFromKeyValue: { value in
            if let date = value as? Date {
                return AllCardsPageContentView.dateFormatter.string(from: date)
            }
            return ""
        })
    ]

    private enum ListType {
        case allNotes
        case privateNotes
        case publicNotes
    }
    @State private var listType: ListType = .allNotes

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: BeamSpacing._20) {
                Spacer()
                ButtonLabel("All (\(model.allNotesItems.count))", state: listType == .allNotes ? .active : .normal) {
                    listType = .allNotes
                }
                Separator()
                ButtonLabel("Public (\(model.publicNotesItems.count))", state: listType == .publicNotes ? .active : .normal) {
                    listType = .publicNotes
                }
                Separator()
                ButtonLabel("Private (\(model.privateNotesItems.count))",
                            state: listType == .privateNotes ? .active : .normal) {
                    listType = .privateNotes
                }
                GeometryReader { geo in
                    ButtonLabel(icon: "editor-options") {
                        showGlobalContextualMenu(at: geo.frame(in: .global).offsetBy(dx: -BeamSpacing._80, dy: -BeamSpacing._80).origin, allowImports: true)
                    }
                    .frame(width: 16)
                }
                .padding(.trailing, 3)
                .frame(width: 22)
                .padding(.leading, BeamSpacing._80)
            }
            .frame(height: 22)
            .padding(.vertical, 3)
            TableView(items: currentNotesList, columns: columns,
                      creationRowTitle: listType == .publicNotes ? "New Public Card" : "New Private Card",
                      shouldReloadData: $model.shouldReloadData) { (newText, row) in
                onEditingText(newText, row: row, in: currentNotesList)
            } onSelectionChanged: { (selectedIndexes) in
                Logger.shared.logDebug("selected: \(selectedIndexes.map { $0 })")
                DispatchQueue.main.async {
                    selectedRowsIndexes = selectedIndexes
                }
            } onHover: { (hoveredIndex, frame) in
                let notesList = currentNotesList
                hoveredRowIndex = (hoveredIndex ?? notesList.count) >= notesList.count ? nil : hoveredIndex
                hoveredRowFrame = frame
            } onMouseDown: { (rowIndex, column) in
                handleMouseDown(for: rowIndex, column: column)
            } onRightMouseDown: { (rowIndex, _, location) in
                let forRow = selectedRowsIndexes.contains(rowIndex) ? nil : rowIndex
                showGlobalContextualMenu(at: location, for: forRow)
            }
            .overlay(
                GeometryReader { geo in
                    ButtonLabel(icon: "editor-options") {
                        showContextualMenuForHoveredRow(tableViewGeometry: geo)
                    }
                    .opacity(selectedRowsIndexes.count <= 1 && hoveredRowIndex != nil && hoveredRowFrame != nil ? 1.0 : 0.0)
                    .offset(x: -TableView.rowHeight, y: geo.frame(in: .global).maxY - (hoveredRowFrame?.maxY ?? 0) + 5)
                }
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            model.data = data
            model.refreshAllNotes()
        }
        .onDisappear {
            undoManager?.removeAllActions()
        }
    }

    func handleMouseDown(for row: Int, column: TableViewColumn) {
        guard column.isLink else { return }
        let items = currentNotesList
        let item = items[row]
        state.navigateToNote(id: item.id)
    }

    func showContextualMenuForHoveredRow(tableViewGeometry: GeometryProxy) {
        let tableViewFrame = tableViewGeometry.frame(in: .global)
        let point = CGPoint(x: tableViewFrame.minX - TableView.rowHeight, y: (hoveredRowFrame?.maxY ?? 0) - TableView.rowHeight - BeamSpacing._40)
        showGlobalContextualMenu(at: point, for: hoveredRowIndex)
    }

    func showGlobalContextualMenu(at: NSPoint, for row: Int? = nil, allowImports: Bool = false) {
        let notes = currentNotesList
        var selectedNotes: [BeamNote] = []
        let docManager = data.documentManager
        if let row = row, row < notes.count {
            let item = notes[row]
            if let note = item.note ?? item.note(withDocumentManager: docManager) {
                selectedNotes = [note]
            }
        } else {
            selectedNotes = notes.enumerated().filter { i, _ in selectedRowsIndexes.contains(i) }.compactMap({ _, item -> BeamNote? in
                item.note ?? item.note(withDocumentManager: docManager)
            })
        }
        let handler = AllCardsContextualMenu(documentManager: docManager, selectedNotes: selectedNotes, onFinish: { shouldReload in
            if shouldReload {
                model.refreshAllNotes()
            }
        })
        handler.delegate = model
        handler.undoManager = self.undoManager
        handler.presentMenuForNotes(at: at, allowImports: allowImports)
    }

    private func onEditingText(_ text: String?, row: Int, in notesList: [NoteTableViewItem]) {
        guard let title = text, !title.isEmpty else {
            return
        }
        if row >= notesList.count {
            let newNote = state.createNoteForQuery(title)
            newNote.isPublic = listType == .publicNotes
            newNote.save(documentManager: data.documentManager)
        } else {
            let item = notesList[row]
            let note = BeamNote.fetchOrCreate(data.documentManager, title: item.title)
            if note.title != title {
                note.updateTitle(title, documentManager: data.documentManager)
                model.refreshAllNotes()
            }
        }
    }
}

struct AllCardsPageContentView_Previews: PreviewProvider {
    static let state = BeamState()
    static var previews: some View {
        AllCardsPageContentView()
            .environmentObject(state)
            .environmentObject(state.data)
            .background(BeamColor.Generic.background.swiftUI)
    }
}

private enum ColumnIdentifiers {
    static let CheckColumn = NSUserInterfaceItemIdentifier("CheckColumnID")
    static let TitleColumn = NSUserInterfaceItemIdentifier("title")
    static let WordsColumn = NSUserInterfaceItemIdentifier("words")
    static let MentionsColumn = NSUserInterfaceItemIdentifier("mentions")
    static let CreatedColumn = NSUserInterfaceItemIdentifier("createdAt")
    static let UpdatedColumn = NSUserInterfaceItemIdentifier("updatedAt")
}

private enum CellIdentifiers {
    static let DefaultCell = NSUserInterfaceItemIdentifier("DefaultCellID")
}

@objcMembers
private class NoteTableViewItem: TableViewItem {
    var id: UUID {
        note?.id ?? document.id
    }

    var isPublic: Bool {
        note?.isPublic ?? document.isPublic
    }

    var note: BeamNote? {
        didSet {
            words = note?.textStats.wordsCount ?? words
        }
    }
    private var document: DocumentStruct

    var title: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var words: Int = -1
    var mentions: Int = -1

    init(document: DocumentStruct, note: BeamNote?) {
        self.note = note
        self.document = document
        title = note?.title ?? document.title
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        words = note?.textStats.wordsCount ?? -1
    }

    func note(withDocumentManager documentManager: DocumentManager) -> BeamNote? {
        note ?? BeamNote.fetch(documentManager, id: id, keepInMemory: false, decodeChildren: false)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherNote = object as? NoteTableViewItem else {
            return false
        }
        return note?.id == otherNote.note?.id
    }
}

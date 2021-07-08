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

    var data: BeamData?

    @Published fileprivate var allNotes = [DocumentStruct]() {
        didSet {
            updateNoteItemsFromAllNotes()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    @Published fileprivate var allNotesItems = [NoteTableViewItem]()
    @Published fileprivate var privateNotesItems = [NoteTableViewItem]()
    @Published fileprivate var publicNotesItems = [NoteTableViewItem]()

    init() {
        CoreDataContextObserver.shared
            .publisher(for: .anyDocumentChange)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { _ in
                self.refreshAllNotes()
            }
            .store(in: &cancellables)
    }

    fileprivate func refreshAllNotes() {
        guard let documentManager = data?.documentManager else { return }
        allNotes = documentManager.loadAll()
    }

    fileprivate func updateNoteItemsFromAllNotes() {
        guard let documentManager = data?.documentManager else { return }
        allNotesItems = allNotes.map { doc in
            var note: BeamNote
            do {
                note = try BeamNote.instanciateNote(documentManager, doc, keepInMemory: false, decodeChildren: false)
            } catch {
                note = BeamNote.fetchOrCreate(documentManager, title: doc.title)
            }
            return NoteTableViewItem(document: doc, note: note)
        }
        publicNotesItems = allNotesItems.filter({ $0.note.isPublic })
        privateNotesItems = allNotesItems.filter({ !$0.note.isPublic })
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

    private var columns = [
        TableViewColumn(key: "checkbox", title: "", type: TableViewColumn.ColumnType.CheckBox,
                        sortable: false, resizable: false, width: 16),
        TableViewColumn(key: "title", title: "Title", editable: true,
                        isLink: true, sortableDefaultAscending: true, width: 200),
        TableViewColumn(key: "words", title: "Words", width: 50, stringFromKeyValue: { "\($0 ?? "")" }),
        TableViewColumn(key: "mentions", title: "Mentions", width: 70, stringFromKeyValue: { "\($0 ?? "")" }),
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
            TableView(items: currentNotesList, columns: columns, creationRowTitle: listType == .publicNotes ? "New Public Card" : "New Private Card") { (newText, row) in
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
        state.navigateToNote(named: item.title)
    }

    func showContextualMenuForHoveredRow(tableViewGeometry: GeometryProxy) {
        let tableViewFrame = tableViewGeometry.frame(in: .global)
        let point = CGPoint(x: tableViewFrame.minX - TableView.rowHeight, y: (hoveredRowFrame?.maxY ?? 0) - TableView.rowHeight - BeamSpacing._40)
        showGlobalContextualMenu(at: point, for: hoveredRowIndex)
    }

    func showGlobalContextualMenu(at: NSPoint, for row: Int? = nil, allowImports: Bool = false) {
        let notes = currentNotesList
        var selectedNotes: [BeamNote] = []
        if let row = row, row < notes.count {
            selectedNotes = [notes[row].note]
        } else {
            selectedNotes = notes.enumerated().filter { i, _ in selectedRowsIndexes.contains(i) }.map({ _, el -> BeamNote in
                el.note
            })
        }
        let handler = AllCardsContextualMenu(documentManager: state.data.documentManager, selectedNotes: selectedNotes, onFinish: { shouldReload in
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
    var note: BeamNote

    var title: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var words: Int = 0
    var mentions: Int = 0
    init(document: DocumentStruct, note: BeamNote) {
        self.note = note
        title = note.title
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        words = note.textStats.wordsCount
        mentions = note.linksAndReferences.count
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherNote = object as? NoteTableViewItem else {
            return false
        }
        return note.id == otherNote.note.id
    }
}

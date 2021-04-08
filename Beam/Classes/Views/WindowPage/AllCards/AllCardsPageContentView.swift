//
//  AllCardsPageContentView.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2021.
//

import SwiftUI
import BeamCore

struct AllCardsPageContentView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var data: BeamData

    @State private var allNotes = [BeamNote]() {
        didSet {
            privateNotes = allNotes.filter({ !$0.isPublic })
            publicNotes = allNotes.filter({ $0.isPublic })
            allNotesItems = allNotes.map { NoteTableViewItem($0) }
            publicNotesItems = publicNotes.map { NoteTableViewItem($0) }
            privateNotesItems = privateNotes.map { NoteTableViewItem($0) }
        }
    }
    @State private var privateNotes = [BeamNote]()
    @State private var publicNotes = [BeamNote]()

    @State private var allNotesItems = [NoteTableViewItem]()
    @State private var privateNotesItems = [NoteTableViewItem]()
    @State private var publicNotesItems = [NoteTableViewItem]()

    private var currentNotesList: [NoteTableViewItem] {
        switch listType {
        case .publicNotes:
            return publicNotesItems
        case .privateNotes:
            return privateNotesItems
        default:
            return allNotesItems
        }
    }

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
        TableViewColumn(key: "checkbox", title: "", type: TableViewColumn.ColumnType.CheckBox, sortable: false, resizable: false, width: 16),
        TableViewColumn(key: "title", title: "Title", editable: true, width: 200),
        TableViewColumn(key: "words", title: "Words", width: 50, stringFromKeyValue: { "\($0 ?? "")" }),
        TableViewColumn(key: "mentions", title: "Mentions", width: 70, stringFromKeyValue: { "\($0 ?? "")" }),
        TableViewColumn(key: "createdAt", title: "Created", stringFromKeyValue: { value in
            if let date = value as? Date {
                return AllCardsPageContentView.dateFormatter.string(from: date)
            }
            return ""
        }),
        TableViewColumn(key: "updatedAt", title: "Updated", stringFromKeyValue: { value in
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
                ButtonLabel("All (\(allNotes.count))", state: listType == .allNotes ? .active : .normal) {
                    listType = .allNotes
                }
                Separator()
                ButtonLabel("Public (\(publicNotes.count))", state: listType == .publicNotes ? .active : .normal) {
                    listType = .publicNotes
                }
                Separator()
                ButtonLabel("Private (\(privateNotes.count))", state: listType == .privateNotes ? .active : .normal) {
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
            TableView(items: currentNotesList, columns: columns, creationRowTitle: listType == .publicNotes ? "New Public Card" : "New Private Card", onEditingText: { (newText, row) in
                onEditingText(newText, row: row, in: currentNotesList)
            }, onSelectionChanged: { (selectedIndexes) in
                Logger.shared.logDebug("selected: \(selectedIndexes.map { $0 })")
                DispatchQueue.main.async {
                    selectedRowsIndexes = selectedIndexes
                }
            }, onHover: { (hoveredIndex, frame) in
                let notesList = currentNotesList
                hoveredRowIndex = (hoveredIndex ?? notesList.count) >= notesList.count ? nil : hoveredIndex
                hoveredRowFrame = frame
            }, onRightMouseDown: { (rowIndex, location) in
                let forRow = selectedRowsIndexes.contains(rowIndex) ? nil : rowIndex
                showGlobalContextualMenu(at: location, for: forRow)
            })
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
            refreshAllNotes()
        }
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
        let handler = AllCardsContextualMenu(documentManager: state.data.documentManager, selectedNotes: selectedNotes) { (reload) in
            if reload {
                refreshAllNotes()
            }
        }
        handler.presentMenuForNotes(at: at, allowImports: allowImports)
    }

    private func refreshAllNotes() {
        allNotes = data.documentManager.loadDocuments().map { BeamNote.fetchOrCreate(data.documentManager, title: $0.title) }
    }

    private func onEditingText(_ text: String?, row: Int, in notesList: [NoteTableViewItem]) {
        guard let title = text, !title.isEmpty else {
            return
        }
        if row >= notesList.count {
            let newNote = state.createNoteForQuery(title)
            newNote.isPublic = listType == .publicNotes
            newNote.save(documentManager: data.documentManager) { _ in
                refreshAllNotes()
            }
        } else {
            let item = notesList[row]
            let note = BeamNote.fetchOrCreate(data.documentManager, title: item.title)
            if note.title != title {
                note.title = title
                note.save(documentManager: data.documentManager) { _ in
                    refreshAllNotes()
                }
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
    init(_ note: BeamNote) {
        self.note = note
        self.title = note.title
        if let doc = note.documentStruct {
            createdAt = doc.createdAt
            updatedAt = doc.updatedAt
        }
        words = note.wordsCount()
        mentions = note.references.count
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherNote = object as? NoteTableViewItem else {
            return false
        }
        return note.id == otherNote.note.id
    }
}

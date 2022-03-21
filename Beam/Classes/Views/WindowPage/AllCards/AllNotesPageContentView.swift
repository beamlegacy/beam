//
//  AllNotesPageContentView.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2021.
//

import SwiftUI
import BeamCore
import Combine

struct AllNotesPageContentView: View {
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

    @StateObject private var model = AllNotesPageViewModel()
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

    static private let secondaryCellFont = BeamFont.regular(size: 10).nsFont
    static private let secondaryCellTextColor = BeamColor.AlphaGray.nsColor
    static private let secondaryCellSelectedColor = BeamColor.combining(lightColor: .AlphaGray, darkColor: .LightStoneGray).nsColor
    private let columns = [
        TableViewColumn(key: ColumnID.checkbox.rawValue, title: "", type: .CheckBox,
                        sortable: false, resizable: false, width: 25, visibleOnlyOnRowHoverOrSelected: true),
        TableViewColumn(key: ColumnID.title.rawValue, title: loc("Title"),
                        editable: true, isLink: true,
                        sortableDefaultAscending: true, sortableCaseInsensitive: true, width: 200),
        TableViewColumn(key: ColumnID.words.rawValue, title: loc("Words"),
                        width: 70, font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: ColumnID.mentions.rawValue, title: loc("Links"),
                        width: 80, font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: ColumnID.createdAt.rawValue, title: loc("Created"), font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: { value in
            if let date = value as? Date {
                return AllNotesPageContentView.dateFormatter.string(from: date)
            }
            return ""
        }),
        TableViewColumn(key: ColumnID.updatedAt.rawValue, title: loc("Updated"),
                        isInitialSortDescriptor: true, font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: { value in
            if let date = value as? Date {
                return AllNotesPageContentView.dateFormatter.string(from: date)
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

    private var cardsFilters: some View {
        HStack(alignment: .center, spacing: BeamSpacing._20) {
            ButtonLabel("All (\(model.allNotesItems.count))", state: listType == .allNotes ? .active : .normal) {
                listType = .allNotes
            }
            Separator()
                .frame(height: 16)
            ButtonLabel("Published (\(model.publicNotesItems.count))", state: listType == .publicNotes ? .active : .normal) {
                listType = .publicNotes
            }
            Separator()
                .frame(height: 16)
            ButtonLabel("Private (\(model.privateNotesItems.count))",
                        state: listType == .privateNotes ? .active : .normal) {
                listType = .privateNotes
            }
        }
    }

    private var pageTitle: String {
        guard model.isAuthenticated, let username = model.username else {
            return "All Notes"
        }
        return username
    }

    private var creationRowPlaceholder: String {
        if let publishingNoteTitle = model.publishingNoteTitle {
            return loc("Publishing '\(publishingNoteTitle)'...")
        }
        return listType == .publicNotes ? loc("New Published Note") : loc("New Private Note")
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: BeamSpacing._20) {
                HStack(spacing: BeamSpacing._20) {
                    Text(pageTitle)
                        .font(BeamFont.medium(size: PreferencesManager.editorFontSizeHeadingOne).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .padding(.leading, 35)
                    Icon(name: "editor-breadcrumb_down", width: 12, color: BeamColor.LightStoneGray.swiftUI)
                }
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onEnded({ v in
                    showGlobalContextualMenu(at: v.location.swiftUISafeTopLeftPoint(in: nil), allowImports: true)
                }))
                Spacer()
                if model.isAuthenticated {
                    cardsFilters
                } else {
                    ButtonLabel(loc("Connect to Beam to publish your notes")) {
                        model.showConnectWindow()
                    }
                }
            }
            .frame(height: 22)
            .padding(.top, 85)
            .padding(.trailing, 20)
            TableView(hasSeparator: false, items: currentNotesList, columns: columns,
                      creationRowTitle: creationRowPlaceholder,
                      isCreationRowLoading: model.publishingNoteTitle != nil,
                      shouldReloadData: $model.shouldReloadData,
                      sortDescriptor: model.sortDescriptor) { (newText, row) in
                onEditingText(newText, row: row, in: currentNotesList)
            } onSelectionChanged: { (selectedIndexes) in
                Logger.shared.logDebug("selected: \(selectedIndexes.map { $0 })")
                DispatchQueue.main.async {
                    selectedRowsIndexes = selectedIndexes
                }
            } onHover: { (hoveredIndex, frame) in
                let notesList = currentNotesList
                guard let hoveredIndex = hoveredIndex, hoveredIndex < notesList.count else {
                    hoveredRowIndex = nil
                    hoveredRowFrame = nil
                    return
                }
                hoveredRowIndex = hoveredIndex
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
                    .opacity(hoveredRowIndex != nil && hoveredRowFrame != nil ? 1.0 : 0.0)
                    .offset(x: -32, y: (hoveredRowFrame?.minY ?? 0) - geo.safeTopLeftGlobalFrame(in: nil).minY + 3)
                }
            )
            .disabled(model.publishingNoteTitle != nil)
            .frame(maxHeight: .infinity)
            .background(Color.clear
                    .onHover { hovering in
                        if !hovering {
                            hoveredRowIndex = nil
                        }
                    }
                    .padding(.leading, -32) // shifted for hover options menu 
            )
        }
        .padding(.horizontal, 140)
        .frame(maxWidth: .infinity)
        .id(model.id)
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
        let tableViewFrame = tableViewGeometry.safeTopLeftGlobalFrame(in: nil)
        let point = CGPoint(x: tableViewFrame.minX - TableView.rowHeight - BeamSpacing._40, y: (hoveredRowFrame?.maxY ?? 0) + BeamSpacing._40)
        let forRow = selectedRowsIndexes.contains(hoveredRowIndex ?? -1) ? nil : hoveredRowIndex
        showGlobalContextualMenu(at: point, for: forRow)
    }

    func showGlobalContextualMenu(at: NSPoint, for row: Int? = nil, allowImports: Bool = false) {
        let notes = currentNotesList
        var selectedNotes: [BeamNote] = []
        if let row = row, row < notes.count {
            let item = notes[row]
            if let note = item.note ?? item.getNote() {
                selectedNotes = [note]
            }
        } else {
            selectedNotes = notes.enumerated().filter { i, _ in selectedRowsIndexes.contains(i) }.compactMap({ _, item -> BeamNote? in item.getNote()
            })
        }
        let handler = AllNotesPageContextualMenu(selectedNotes: selectedNotes, onFinish: { shouldReload in
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
            let newNote = state.fetchOrCreateNoteForQuery(title)
            let isPublic = listType == .publicNotes

            //If we create a public note, publish it right after creation, else just save it
            if isPublic {
                model.publishingNoteTitle = newNote.title
                BeamNoteSharingUtils.makeNotePublic(newNote, becomePublic: true) { result in
                    DispatchQueue.main.async {
                        model.publishingNoteTitle = nil
                        switch result {
                        case .failure(let e):
                            UserAlert.showError(message: loc("Could not publish note. Try again from the note view."), error: e)
                            // Saving the private note at least and showing it to user.
                            newNote.publicationStatus = .unpublished
                            newNote.save()
                            listType = .privateNotes
                        case .success:
                            model.refreshAllNotes()
                        }
                    }
                }
            } else {
                newNote.save()
            }
        } else {
            let item = notesList[row]
            let note = BeamNote.fetchOrCreate(title: item.title)
            if note.title != title {
                note.updateTitle(title)
                model.refreshAllNotes()
            }
        }
    }
}

struct AllNotesPageContentView_Previews: PreviewProvider {
    static let state = BeamState()
    static var previews: some View {
        AllNotesPageContentView()
            .environmentObject(state)
            .environmentObject(state.data)
            .background(BeamColor.Generic.background.swiftUI)
    }
}

private enum ColumnID: String {
    case checkbox
    case title
    case words
    case mentions
    case createdAt
    case updatedAt
}

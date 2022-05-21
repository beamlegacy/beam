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
    @EnvironmentObject var windowInfo: BeamWindowInfo
    @Environment(\.undoManager) var undoManager

    private var currentNotesList: [NoteTableViewItem] {
        return model.getCurrentNotesList(for: listType)
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

    static private let secondaryCellFont = BeamFont.regular(size: 11).nsFont
    static private let secondaryCellTextColor = BeamColor.AlphaGray.nsColor
    static private let secondaryCellSelectedColor = BeamColor.combining(lightColor: .AlphaGray, darkColor: .LightStoneGray).nsColor
    private let columns = [
        TableViewColumn(key: ColumnID.checkbox.rawValue, title: "", type: .CheckBox,
                        sortable: false, resizable: false, width: 25, visibleOnlyOnRowHoverOrSelected: true),
        TableViewColumn(key: ColumnID.title.rawValue, title: loc("Title"),
                        editable: true, isLink: true,
                        sortableDefaultAscending: true, sortableCaseInsensitive: true, width: 370, font: BeamFont.light(size: 13).nsFont),
        TableViewColumn(key: ColumnID.url.rawValue, title: "URL", type: .IconButton, editable: false, isLink: false, sortable: false, resizable: false,
                        width: 43, font: Self.secondaryCellFont, foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor),
        TableViewColumn(key: ColumnID.words.rawValue, title: loc("Words"),
                        width: 58, font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: ColumnID.mentions.rawValue, title: loc("Links"),
                        width: 50, font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: ColumnID.updatedAt.rawValue, title: loc("Updated"),
                        isInitialSortDescriptor: true, width: 95, font: secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: { value in
            if let date = value as? Date {
                return AllNotesPageContentView.dateFormatter.string(from: date)
            }
            return ""
        })
    ]

    enum ListType {
        case allNotes
        case privateNotes
        case publicNotes
        case onProfileNotes
    }
    @State private var listType: ListType = .allNotes

    private var cardsFilters: some View {
        switch self.listType {
        case .allNotes:
            return Text("All (\(model.getCurrentNotesList(for: .allNotes).count))")
        case .privateNotes:
            return Text("Private (\(model.getCurrentNotesList(for: .privateNotes).count))")
        case .publicNotes:
            return Text("Published (\(model.getCurrentNotesList(for: .publicNotes).count))")
        case .onProfileNotes:
            return Text("On Profile (\(model.getCurrentNotesList(for: .onProfileNotes).count))")
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

        if listType == .publicNotes {
            return model.publicNotesItems.count == 0 ? loc("You haven’t published any note yet. Start today!") : loc("New Published Note")
        }

        if listType == .onProfileNotes {
            return model.onProfileNotesItems.count == 0 ? loc("You haven’t published any note to your profile yet. Start today!") : loc("New Published on Profile Note")
        }

        return loc("New Private Note")
    }

    private var compactWindowWidth: Bool {
        return windowInfo.windowFrame.size.width < 1024
    }

    @State private var justCopiedLink = false
    var body: some View {
        VStack(spacing: 35) {
            HStack(alignment: .center, spacing: BeamSpacing._20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: BeamSpacing._80) {
                        Text(pageTitle)
                            .font(BeamFont.regular(size: 24).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                        Icon(name: "editor-options", width: 16, color: BeamColor.LightStoneGray.swiftUI)
                    }
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onEnded({ v in
                        showGlobalContextualMenu(at: v.location.swiftUISafeTopLeftPoint(in: nil), allowImports: true)
                    }))

                    HStack {
                        if let profileLink = BeamNoteSharingUtils.getProfileLink() {
                            MinimalUnderlineButton(text: profileLink.urlStringWithoutScheme, font: BeamFont.regular(size: 12).swiftUI, foregroundColor: BeamColor.LightStoneGray.swiftUI) {
                                if let state = AppDelegate.main.windows.first?.state {
                                    state.mode = .web
                                    _ = state.createTab(withURLRequest: URLRequest(url: profileLink), originalQuery: nil)
                                }
                            }
                        } else {
                            ButtonLabel(loc("Connect to Beam to publish your notes")) {
                                model.showConnectWindow(withConfirmationAlert: false)
                            }
                        }

                        Spacer()

                        HStack(spacing: BeamSpacing._20) {
                            Text("View:")
                                .font(BeamFont.regular(size: 12).swiftUI)
                                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                            cardsFilters
                                .font(BeamFont.regular(size: 12).swiftUI)
                                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                            Icon(name: "editor-breadcrumb_down", width: 8, color: BeamColor.LightStoneGray.swiftUI)
                        }
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onEnded({ v in
                            showFiltersContextualMenu(at: v.location.swiftUISafeTopLeftPoint(in: nil))
                        }))
                    }
                }
            }
            .frame(height: 22)
            .padding(.top, 97)
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
            .padding(.leading, -34)
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
        .frame(minWidth: 600, maxWidth: 900)
        .padding(.horizontal, compactWindowWidth == true ? 100 : 214)
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

    func showFiltersContextualMenu(at origin: NSPoint) {
        var notes: [BeamNote] = []
        for item in currentNotesList {
            guard let note = item.note ?? item.getNote() else { continue }
            notes.append(note)
        }

        let menu = AllNotesPageFiltersContextualMenu(viewModel: model, selectedListType: listType) { newlySelectedListType in
            self.listType = newlySelectedListType
        }
        menu.presentMenu(at: origin)
    }

    private func onEditingText(_ text: String?, row: Int, in notesList: [NoteTableViewItem]) {
        guard let title = text, !title.isEmpty else {
            return
        }
        if row >= notesList.count {
            let newNote = state.fetchOrCreateNoteForQuery(title)
            let isPublic = listType == .publicNotes
            let publishOnProfile = listType == .onProfileNotes

            //If we create a public note, publish it right after creation, else just save it
            if isPublic || publishOnProfile {
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
                            if publishOnProfile {
                                BeamNoteSharingUtils.updatePublicationGroup(newNote, group: ["profile"]) { _ in
                                    model.refreshAllNotes()
                                }
                            } else {
                                model.refreshAllNotes()
                            }
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
    case url
    case words
    case mentions
    case createdAt
    case updatedAt
}

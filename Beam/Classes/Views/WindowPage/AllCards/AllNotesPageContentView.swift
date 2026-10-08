//
//  AllNotesPageContentView.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2021.
//

import SwiftUI
import BeamCore
import Combine

struct AllNotesPageContentView: View, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo
    @Environment(\.undoManager) var undoManager

    private var currentNotesList: [NoteTableViewItem] {
        model.allNotesItems
    }

    @StateObject private var model = AllNotesPageViewModel()
    @State private var selectedRowsIndexes = IndexSet()
    @State private var hoveredRowIndex: Int?
    @State private var hoveredRowFrame: NSRect?
    @State private var showTabGroupNotes = false

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
                        sortableDefaultAscending: true, sortableCaseInsensitive: true, width: 200, font: BeamFont.light(size: 13).nsFont),
        TableViewColumn(key: ColumnID.words.rawValue, title: loc("Words"), resizable: false,
                        width: 58, font: Self.secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: ColumnID.links.rawValue, title: loc("Links"),
                        resizable: false,
                        width: 50, font: Self.secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: Self.loadingIntValueString),
        TableViewColumn(key: ColumnID.updatedAt.rawValue, title: loc("Updated"), isInitialSortDescriptor: true,
                        resizable: false, width: 95, font: Self.secondaryCellFont,
                        foregroundColor: Self.secondaryCellTextColor, selectedForegroundColor: Self.secondaryCellSelectedColor,
                        stringFromKeyValue: { value in
                            if let date = value as? Date {
                                return AllNotesPageContentView.dateFormatter.string(from: date)
                            }
                            return ""
                        })
    ]

    private var cardsFilters: some View {
        Text("All (\(model.allNotesItems.count))")
    }

    private var compactWindowWidth: Bool {
        let threshold: CGFloat = 1024
        if let window = windowInfo.window as? BeamWindow {
            return window.estimatedContentViewWidth < threshold
        } else {
            return windowInfo.windowFrame.width < threshold
        }
    }

    @State private var buttonFrameInGlobalCoordinates: CGRect?
    private struct ButtonFramePreferenceKey: FramePreferenceKey {}

    private var geometryReaderView: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear.preference(key: ButtonFramePreferenceKey.self, value: frame)
        }
    }

    var body: some View {
        VStack(spacing: 35) {
            HStack(alignment: .center, spacing: BeamSpacing._20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: BeamSpacing._80) {
                        Text("All Notes")
                            .font(BeamFont.regular(size: 24).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                        Icon(name: "editor-options", width: 16, color: BeamColor.LightStoneGray.swiftUI)
                            .blendModeLightMultiplyDarkScreen()
                            .padding(.top, 4)
                    }
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onEnded({ v in
                        showGlobalContextualMenu(at: v.location.swiftUISafeTopLeftPoint(in: nil), allowImports: true)
                    }))

                    HStack {
                        Spacer()

                        ButtonLabel(customView: { hovered, _ in
                            AnyView(
                                HStack(spacing: BeamSpacing._20) {
                                    Text("View:")
                                        .font(BeamFont.regular(size: 12).swiftUI)
                                        .foregroundColor(hovered ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                                    cardsFilters
                                        .font(BeamFont.regular(size: 12).swiftUI)
                                        .foregroundColor(hovered ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                                    Icon(name: "editor-breadcrumb_down", width: 8, color: hovered ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                                        .blendModeLightMultiplyDarkScreen()
                                }
                            )
                        }, state: .normal, customStyle: ButtonLabelStyle.minimalButtonLabel, action: {
                            showFiltersContextualMenu()
                        })
                        .background(geometryReaderView)
                        .onPreferenceChange(ButtonFramePreferenceKey.self) { frame in
                            buttonFrameInGlobalCoordinates = frame
                        }
                    }
                }
            }
            .frame(height: 22)
            .padding(.top, 97)
            .padding(.leading, 9)
            GeometryReader { proxy in
                TableView(hasSeparator: false,
                          items: currentNotesList,
                          columns: tableColumns(for: proxy.frame(in: .local).size.width),
                          creationRowTitle: loc("New Note"),
                          isCreationRowLoading: false,
                          shouldReloadData: $model.shouldReloadData,
                          sortDescriptor: $state.allNotesSortDescriptor) { (newText, row) in
                    onEditingText(self, newText, row: row, in: currentNotesList)
                } onSelectionChanged: { (selectedIndexes) in
                    Logger.shared.logDebug("selected: \(selectedIndexes.map { $0 })")
                    // Here we dispatch to avoid a SwiftUI state update during the current view update
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
                } onMouseDown: { (rowIndex, column, modifier) in
                    handleMouseDown(for: rowIndex, column: column, modifiers: modifier)
                } onRightMouseDown: { (rowIndex, _, location) in
                    let forRow = selectedRowsIndexes.contains(rowIndex) ? nil : rowIndex
                    showGlobalContextualMenu(at: location, for: forRow)
                }
            }
            .overlay(
                GeometryReader { geo in
                    if selectedRowsIndexes.contains(hoveredRowIndex ?? 0) || selectedRowsIndexes.isEmpty {
                        ButtonLabel(icon: "editor-options") {
                            showContextualMenuForHoveredRow(tableViewGeometry: geo)
                        }
                        .opacity(hoveredRowIndex != nil && hoveredRowFrame != nil ? 1.0 : 0.0)
                        .offset(x: -32, y: (hoveredRowFrame?.minY ?? 0) - geo.safeTopLeftGlobalFrame(in: nil).minY + 3)
                    }
                }
            )
            .padding(.leading, -25)
            .frame(maxHeight: .infinity)
            .background(Color.clear
                .onHover { hovering in
                    if !hovering {
                        hoveredRowIndex = nil
                    }
                }
                .padding(.leading, -64) // shifted for hover options menu
            )
        }
        .frame(minWidth: 200, maxWidth: 900)
        .padding(.horizontal, compactWindowWidth ? 60 : 204)
        .id(model.id)
        .onChange(of: state.showDailyNotes) { newValue in
            model.setShowDailyNotes(newValue)
        }
        .onChange(of: showTabGroupNotes) { newValue in
            model.setShowTabGroupNotes(newValue)
        }
        .onAppear {
            model.setShowDailyNotes(state.showDailyNotes)
            model.refreshAllNotes()
        }
    }

    func handleMouseDown(for row: Int, column: TableViewColumn, modifiers: NSEvent.ModifierFlags) {
        guard column.isLink else { return }
        let items = currentNotesList
        let item = items[row]

        if modifiers.contains(.shift) {
            state.openNoteInNewWindow(id: item.id)
        } else if modifiers.contains(.command) {
            state.navigateToNote(id: item.id, in: .splitView)
        } else {
            state.navigateToNote(id: item.id, in: .main)
        }
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

    private func showFiltersContextualMenu() {
        guard let window = AppDelegate.main.window,
              let buttonFrame = buttonFrameInGlobalCoordinates?.swiftUISafeTopLeftGlobalFrame(in: window) else { return }

        let menu = AllNotesPageFiltersContextualMenu(viewModel: model, state: state)
        menu.presentMenu(at: CGPoint(x: buttonFrame.origin.x, y: buttonFrame.maxY + 6))
    }

    private func onEditingText(_ source: BeamDocumentSource, _ text: String?, row: Int, in notesList: [NoteTableViewItem]) {
        guard let title = text, !title.isEmpty else {
            return
        }
        if row >= notesList.count {
            guard let newNote = try? state.fetchOrCreateNoteForQuery(title) else { return }
            _ = newNote.save(source)
        } else {
            let item = notesList[row]
            guard let note = try? BeamNote.fetchOrCreate(source, title: item.title) else { return }
            if note.title != title {
                note.updateTitle(source, title)
                model.refreshAllNotes()
            }
        }
    }

    private func tableColumns(for width: CGFloat) -> [TableViewColumn] {
        let isSmallWidth = width < 465
        var columns = self.columns
        columns[2].hidden = isSmallWidth // words
        columns[3].hidden = isSmallWidth // links
        return columns
    }
}

struct AllNotesPageContentView_Previews: PreviewProvider {
    static let state = BeamState()
    static var previews: some View {
        AllNotesPageContentView()
            .environmentObject(state)
            .environmentObject(state.data)
            .environmentObject(BeamWindowInfo())
            .background(BeamColor.Generic.background.swiftUI)
    }
}

private enum ColumnID: String {
    case checkbox
    case title
    case words
    case links
    case createdAt
    case updatedAt
}

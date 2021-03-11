//
//  DestinationNodePicker.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/01/2021.
//

import AppKit
import SwiftUI
import Foundation

struct DestinationNotePicker: View {
    var tab: BrowserTab
    @EnvironmentObject var state: BeamState
    @State var isHovering = false
    @State var isMouseDown = false

    var title: String {
        get {
            let t = state.destinationCardName
            return t == state.data.todaysName ? "Destination Card" : t
        }
        set {
            state.destinationCardName = newValue
        }

    }
    private var isEditing: Bool {
        state.destinationCardIsFocused
    }
    private func setIsEditing(_ editing: Bool) {
        state.destinationCardIsFocused = editing
    }

    var body: some View {

        let isEditingBinding = Binding<Bool>(get: {
            isEditing
        }, set: {
            setIsEditing($0)
        })

        return GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isMouseDown ? Color(.destinationNoteBorderColor) : Color(.transparent))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isEditing || isHovering ? Color(.destinationNoteBorderColor) : Color(.transparent))
                    )
                    .onHover(perform: { hovering in
                        isHovering = hovering
                    })
                    .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    isMouseDown = true
                                }
                                .onEnded { _ in
                                    isMouseDown = false
                                })
                HStack(spacing: 2) {

//                    For now we don't display the icon. Might come back soon
//                    if !isEditing {
//                        Icon(name: "field-card_destination", color: isHovering || isMouseDown ? Color(.destinationNoteActiveTextColor) : Color(.destinationNoteTextColor))
//                            .frame(width: 16, height: 16)
//                    }
                    if isEditing {
                        BeamTextField(
                            text: $state.destinationCardName,
                            isEditing: isEditingBinding,
                            placeholder: "Destination Card",
                            font: .systemFont(ofSize: 12),
                            textColor: .destinationNoteActiveTextColor,
                            placeholderColor: NSColor.omniboxPlaceholderTextColor,
                            selectedRanges: state.destinationCardNameSelectedRange
                        ) { newName in
                            Logger.shared.logInfo("New name \(newName)", category: .ui)
                            state.destinationCardNameSelectedRange = nil
                            updatePopover(geometry.frame(in: .global))
                        } onCommit: {
                            state.bidirectionalPopover?.doCommand(.insertNewline)
                        } onEscape: {
                            cancelSearch()
                        } onCursorMovement: { move -> Bool in
                            switch move {
                            case .up:
                                state.bidirectionalPopover?.doCommand(.moveUp)
                                return true
                            case .down:
                                state.bidirectionalPopover?.doCommand(.moveDown)
                                return true
                            default:
                                return false
                            }
                        } onStartEditing: {
                            Logger.shared.logInfo("on start editing", category: .ui)
                            createPopoverIfNeeded(with: geometry.frame(in: .global))
                            state.destinationCardNameSelectedRange = [state.destinationCardName.wholeRange]
                        } onStopEditing: {
                            cancelSearch()
                        }
                        .onAppear(perform: {
                            state.destinationCardName = tab.note.title
                        })
                    } else {
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isHovering || isMouseDown ? Color(.destinationNoteActiveTextColor) : Color(.destinationNoteTextColor))
                            .onTapGesture {
                                setIsEditing(true)
                            }
                    }
                }
                .padding([.top, .bottom, .trailing], 8)
                .padding(.leading, isEditing ? 8 : 6)
            }
        }.frame(width: isEditing ? 230 : 130)
    }

    func createPopoverIfNeeded(with frame: NSRect) {
        guard state.bidirectionalPopover == nil else { return }
        state.bidirectionalPopover = BidirectionalPopover()

        guard let popover = state.bidirectionalPopover,
              let window = tab.webView.window,
              let view = window.contentView else { return }
        view.addSubview(popover)
        popover.autoresizingMask = [.minXMargin, .minYMargin]
        updatePopover(frame)

        popover.didSelectTitle = { title -> Void in
            // change the tab's destination note
            changeDestinationCard(to: title)
            cancelSearch()
        }
    }

    func updatePopover(_ frame: NSRect) {
        Logger.shared.logInfo("update Popover for query \(state.destinationCardName) \(frame)", category: .ui)
        guard let popover = state.bidirectionalPopover else { return }

        let items = state.destinationCardName.isEmpty ? state.data.documentManager.loadAllDocumentsWithLimit(4) : state.data.documentManager.documentsWithLimitTitleMatch(title: state.destinationCardName, limit: 4)

        popover.items = items.map({ $0.title == state.data.todaysName ? "Journal" : $0.title })
        Logger.shared.logInfo("items: \(popover.items)", category: .ui)
        popover.query = state.destinationCardName

        let position = NSPoint(x: frame.minX, y: (frame.minY - popover.idealSize.height))
        popover.frame = NSRect(origin: position, size: popover.idealSize)
    }

    func changeDestinationCard(to cardName: String) {
        let cardName = cardName.lowercased() == "journal" ? state.data.todaysName : cardName
        state.destinationCardName = cardName
        let note = BeamNote.fetchOrCreate(state.data.documentManager, title: cardName)
        tab.setDestinationNote(note, rootElement: note)
    }

    func cancelSearch() {
        state.bidirectionalPopover?.removeFromSuperview()
        state.bidirectionalPopover = nil
        state.resetDestinationCard()
    }
}

struct DestinationNotePicker_Previews: PreviewProvider {
    static var previews: some View {
        let state = BeamState()
        let tab = BrowserTab(state: state, originalQuery: "original query", note: BeamNote(title: "Query text"))
        let focusedState = BeamState()
        focusedState.destinationCardIsFocused = true
        let itemHeight: CGFloat = 32.0
        return
            VStack {
                DestinationNotePicker(tab: tab).environmentObject(state)
                    .frame(height: itemHeight)
                DestinationNotePicker(tab: tab, isHovering: true).environmentObject(state)
                    .frame(height: itemHeight)
                DestinationNotePicker(tab: tab, isMouseDown: true).environmentObject(state)
                    .frame(height: itemHeight)
                DestinationNotePicker(tab: tab).environmentObject(focusedState)
                    .frame(height: itemHeight)
            }
            .padding()
            .background(Color.white)
    }
}

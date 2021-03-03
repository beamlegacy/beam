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
    var title: String {
        get {
            let t = state.destinationCardName
            return t == state.data.todaysName ? "Journal" : t
        }
        set {
            state.destinationCardName = newValue
        }

    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 7).strokeBorder(state.destinationCardInputIsFirstResponder ? Color.blue : Color.gray )
                if state.changingDestinationCard {
                    BeamTextField(
                        text: $state.destinationCardName,
                        isEditing: $state.changingDestinationCard,
                        isFirstResponder: $state.destinationCardInputIsFirstResponder,
                        placeholder: "destination card",
                        font: .systemFont(ofSize: 16),
                        textColor: NSColor.omniboxTextColor,
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
                    .frame(width: 200, height: 30, alignment: .center)
                    .onAppear(perform: {
                        state.destinationCardName = tab.note.title
                    })
                    .padding(EdgeInsets(top: 0, leading: 3, bottom: 0, trailing: 3))
                } else {
                    Text(title).onTapGesture {
                        state.destinationCardInputIsFirstResponder = true
                        state.changingDestinationCard = true
                    }
                }
            }
        }
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
        Logger.shared.logInfo("update Popover for query \(state.destinationCardName)", category: .ui)
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
        state.destinationCardInputIsFirstResponder = false
        state.changingDestinationCard = false
        state.destinationCardNameSelectedRange = nil
    }
}

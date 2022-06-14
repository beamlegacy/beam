//
//  SidebarListNoteButton.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/05/2022.
//

import SwiftUI
import BeamCore

struct SidebarListNoteButton: View {

    private let maxNoteTitleLength = 40

    @ObservedObject var note: BeamNote
    @ObservedObject var pinnedManager: PinnedNotesManager

    @EnvironmentObject var state: BeamState

    var isSelected = false
    var action: (() -> Void)?

    @State var isHovering: Bool = false
    @State var isPressed: Bool = false

    @State var isHoveringTrailingIcon: Bool = false
    @State var justCopied = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            if isHovering { // This is preliminary work for BE-4114
                let isPinned = pinnedManager.isPinned(note)
                ButtonLabel(icon: isPinned ? "sidebar-pin_fill" : "sidebar-pin", customStyle: smallButtonLabelStyle) {
                    pinnedManager.togglePin(note)
                }.frame(width: 12, height: 12)
            } else {
                Spacer()
                    .frame(width: 12, height: 12)
            }
            HStack {
                Text(titleForNote(note))
                    .lineLimit(1)
                Spacer()
            }.padding(.vertical, 7)
            .contentShape(Rectangle())
            .onTouchDown { isPressed = $0 }
            .if(action != nil) {
                $0.simultaneousGesture(TapGesture().onEnded {
                    action?()
                })
            }
            if note.publicationStatus.isPublic {
                ButtonLabel(icon: "editor-url_link", customStyle: buttonLabelStyle) {
                    BeamNoteSharingUtils.copyLinkToClipboard(for: note, completion: nil)
                    justCopied = true
                }.onHover(perform: { h in
                    isHoveringTrailingIcon = h
                })
            }
        }
        .foregroundColor(foregroundColor)
        .font(textFont)
        .padding(.horizontal, 8)
        .frame(width: 220, height: 30)
        .background(SidebarListBackground(isSelected: isSelected,
                                          isHovering: isHovering,
                                          isPressed: isPressed))
        .onHover {
            isHovering = $0
            if !$0 {
                isPressed = false
            }
        }.contextMenu { Self.contextualMenu(for: note, state: state) }
        .overlay(!isHoveringTrailingIcon ? nil : Tooltip(title: justCopied ? "Link Copied" : "Copy Link", icon: justCopied ? "tool-keep" : nil)
                    .fixedSize()
                    .offset(x: -30, y: 0)
                    .transition(Tooltip.defaultTransition), alignment: .trailing)
    }

    @ViewBuilder static func contextualMenu(for note: BeamNote, state: BeamState) -> some View {
        let isPinned = state.data.pinnedManager.isPinned(note)
        Button(isPinned ? "Unpin" : "Pin") {
            state.data.pinnedManager.togglePin(note)
        }
        Button(note.publicationStatus.isPublic ? "Unpublish" : "Publish") {
            BeamNoteSharingUtils.makeNotePublic(note, becomePublic: !note.publicationStatus.isPublic) { _ in }
        }
        Divider()
        Menu("Export") {
            Button("beamNote…") {
                AppDelegate.main.exportOneNoteToBeamNote(note: note)
            }
        }
        Divider()
        Button("Delete…") {
            note.promptConfirmDelete(for: state)
        }
    }

    private var textFont: Font {
        isSelected ? BeamFont.medium(size: 12).swiftUI : BeamFont.regular(size: 12).swiftUI
    }

    private var foregroundColor: Color {
        BeamColor.Niobium.swiftUI
    }

    private var buttonLabelStyle: ButtonLabelStyle {
        ButtonLabelStyle(horizontalPadding: 0, verticalPadding: 0, activeBackgroundColor: .clear)
    }

    private var smallButtonLabelStyle: ButtonLabelStyle {
        ButtonLabelStyle(horizontalPadding: 0, verticalPadding: 0, iconSize: 12, foregroundColor: BeamColor.AlphaGray.swiftUI, activeBackgroundColor: .clear)
    }

    private func titleForNote(_ note: BeamNote) -> String {
        guard let journalDate = note.type.journalDate else {
            return truncatedTitle(note.title)
        }
        return truncatedTitle(BeamDate.journalNoteTitle(for: journalDate, with: .medium))
    }

    /// Manually truncating text because using maxWidth in SwiftUI makes the Text spread
    private func truncatedTitle(_ title: String) -> String {
        guard title.count > maxNoteTitleLength else { return title }
        return title.prefix(maxNoteTitleLength).trimmingCharacters(in: .whitespaces) + "…"
    }
}

struct SidebarListNoteButton_Previews: PreviewProvider {

    static var note = BeamNote(title: "Baudrillard")

    static var previews: some View {
        SidebarListNoteButton(note: note, pinnedManager: PinnedNotesManager(with: DocumentManager()))
    }
}

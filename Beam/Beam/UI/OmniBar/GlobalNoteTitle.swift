//
//  GlobalNoteTitle.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct GlobalNoteTitle: View {
    var _cornerRadius = CGFloat(7)
    @EnvironmentObject var state: BeamState
    var note: BeamNote
    @State var isHover = false
    @State var isEditing = false
    @State var isRenaming = false
    @State var title = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(Color("OmniboxBackgroundColor").opacity(isHover ? 1 : 0)) .frame(height: 28)
            RoundedRectangle(cornerRadius: _cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 2.5 : 0).frame(height: 28)
            if !isRenaming {
                Text(note.title)
                    .font(.system(size: 16, weight: .heavy))
                    .frame(idealWidth: 600, maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 9)
            } else {
                BTextField(text: $title,
                           isEditing: $isEditing,
                           placeholderText: "note name",
                           onCommit: {
                            withAnimation {
                                isRenaming = false
                                isEditing = false
                                note.title = title
                            }
                           },
                           focusOnCreation: true,
                           textColor: NSColor(named: "OmniboxTextColor"),
                           placeholderTextColor: NSColor(named: "OmniboxPlaceholderTextColor"),
                           name: "NoteRenamer"
                )
                .padding(.top, 8)
                .padding([.leading, .trailing], 9)
                .frame(idealWidth: 600, maxWidth: .infinity)
            }
        }
        .onTapGesture(count: 1, perform: {
            withAnimation {
                isRenaming = true
                title = note.title
            }
        })
        .onHover { h in
            withAnimation {
                isHover = h
            }
        }
        .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 35, idealHeight: 35, maxHeight: 35, alignment: .leading)
    }
}

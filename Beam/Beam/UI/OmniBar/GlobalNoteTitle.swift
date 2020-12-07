//
//  GlobalNoteTitle.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct GlobalNoteTitle: View {
    @EnvironmentObject var state: BeamState
    @State var isHover = false
    @State var isEditing = false
    @State var focusOmniBox = false
    @State var title = ""

    var _cornerRadius = CGFloat(7)
    var note: BeamNote

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius)
                .animation(.default)
                .foregroundColor(Color("OmniboxBackgroundColor")
                                    .opacity(isHover ? 1 : 0)
                ) .frame(height: 28)

            RoundedRectangle(cornerRadius: _cornerRadius)
                .stroke(isEditing ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2.5)
                .animation(.default)
                .frame(height: 28)

            BMTextField(
                text: $title,
                isEditing: $isEditing,
                isFirstResponder: $focusOmniBox,
                placeholder: "note name",
                font: .systemFont(ofSize: 16, weight: .heavy),
                textColor: NSColor(named: "OmniboxTextColor"),
                placeholderColor: NSColor(named: "OmniboxPlaceholderTextColor"),
                onCommit: {
                    note.title = title
                    isEditing = false
                    focusOmniBox = false
                    NSApp.mainWindow?.makeFirstResponder(nil)
                }
            )
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .frame(idealWidth: 600, maxWidth: .infinity)
        }
        .onTapGesture(count: 1, perform: {
            title = note.title
        })
        .onHover { h in
            isHover = h
        }
        .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 35, idealHeight: 35, maxHeight: 35, alignment: .leading)
    }
}

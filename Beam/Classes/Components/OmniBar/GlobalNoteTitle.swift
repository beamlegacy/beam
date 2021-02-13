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
    @State var isHover: Bool = false {
        didSet {
            if isHover {
                NSCursor.iBeam.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
    @State var isEditing = false
    @State var focusOmniBox = false
    @Binding var title: String

    var _cornerRadius = CGFloat(7)
    var note: BeamNote

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius)
                .foregroundColor(Color(.omniboxBackgroundColor)
                                    .opacity(isHover ? 1 : 0)
                ) .frame(height: 28)

            RoundedRectangle(cornerRadius: _cornerRadius)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: isEditing ? 2.5 : 0)
                .frame(height: 28)

            BMTextField(
                text: $title,
                isEditing: $isEditing,
                isFirstResponder: $focusOmniBox,
                placeholder: "note name",
                font: .systemFont(ofSize: 16, weight: .heavy),
                textColor: NSColor.omniboxTextColor,
                placeholderColor: NSColor.omniboxPlaceholderTextColor,
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
            focusOmniBox = true
            isEditing = true
            title = note.title
        })
        .onHover { h in
            withAnimation {
               isHover = h
            }
        }
        .frame(idealWidth: 600, maxWidth: .infinity, minHeight: 35, idealHeight: 35, maxHeight: 35, alignment: .leading)
    }
}

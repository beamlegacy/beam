//
//  JournalView.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/10/2020.
//

import Foundation
import SwiftUI
import Combine

struct JournalView: View {
    var journal: [Note]
    var offset: CGFloat
    @State var isEditing = false

    var body: some View {
        VStack {
            ForEach(journal) { note in
                return VStack {
                    Text(note.title).bold().padding(.leading, 150).frame(maxWidth: .infinity, alignment: .leading)
                    NoteView(note: note,
                             onStartEditing: {
                                withAnimation {
                                    isEditing = true
                                }
                             }
                    )
                }.padding(.top, 20).padding(.bottom, 50)
            }
        }
        .padding(.top, isEditing ? 20: offset)
    }
}

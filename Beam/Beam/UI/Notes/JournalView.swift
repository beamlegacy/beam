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
        ScrollView([.vertical]) {
            ForEach(journal) { note in
                return HStack {
                    Text(note.title)
                        .bold()
                        .padding(.leading)
                        .padding(.trailing)
                        .frame(width: 200, alignment: .topTrailing)
                    NoteView(note: note,
                             onStartEditing: {
                                withAnimation {
                                    isEditing = true
                                }
                             },
                             leadingAlignement: 0
                    )
                }.padding(.top, 20).padding(.bottom, 50)
            }
        }
        .padding(.top, isEditing ? 20 : offset)
    }
}

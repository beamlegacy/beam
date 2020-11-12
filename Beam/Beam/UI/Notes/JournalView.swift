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
            VStack {
                ForEach(journal) { note in
                    return HStack {
                        NoteView(note: note,
                                 onStartEditing: {
                                    withAnimation {
                                        isEditing = true
                                    }
                                 },
                                 leadingAlignement: 185,
                                 showTitle: true
                        )
                        .animation(.none)

                    }.padding(.top, 20).padding(.bottom, 50)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut)
            .padding(.top, isEditing ? 20 : offset)
        }
    }
}

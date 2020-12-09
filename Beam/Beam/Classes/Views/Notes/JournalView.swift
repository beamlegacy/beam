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
    var journal: [BeamNote]
    var journals: [BeamNote] { isEditing ? journal : [journal.first!] }
    var offset: CGFloat
    @State var isEditing = false

    var body: some View {
        ScrollView([.vertical]) {
            VStack {
                ForEach(journals) { note in
                    return NoteView(note: note,
                                 onStartEditing: {
                                    withAnimation {
                                        isEditing = true
                                    }
                                 },
                                 leadingAlignement: 185,
                                 showTitle: true,
                                 scrollable: false
                        )
                        .animation(.none)
                        .padding(.top, 20)
                }
            }
            .animation(.easeInOut)
            .padding(.top, isEditing ? 20 : offset)
        }
    }
}

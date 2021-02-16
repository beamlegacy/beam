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
    @State var isEditing = false

    var data: BeamData
    var journal: [BeamNote]
    var offset: CGFloat

    var body: some View {
        ScrollView([.vertical]) {
            VStack {
                ForEach(journal) { note in
                    NoteView(note: note,
                             onStartEditing: {
                                isEditing = true
                             },
                             leadingAlignement: 185,
                             showTitle: true,
                             scrollable: false,
                             centerText: false
                    )
                }
            }
            .background(GeometryReader { geo -> Color in
                let totalJournal = data.documentManager.countDocumentsWithType(type: .journal)
                if geo.frame(in: .global).origin.y > -5
                    && totalJournal != journal.count {
                    data.updateJournal(with: 2, and: journal.count)
                }
                return Color.clear
            })
            .padding(.top, offset)
        }
        .accessibility(identifier: "journalView")
        .clipped()
    }
}

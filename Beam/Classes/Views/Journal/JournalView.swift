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
    var journals: [BeamNote] { journal }
    var offset: CGFloat

    var body: some View {
        ScrollView([.vertical]) {
            VStack {
                ForEach(journals) { note in
                    NoteView(note: note,
                             onStartEditing: {
                                isEditing = true
                             },
                             leadingAlignement: 185,
                             showTitle: true,
                             scrollable: false
                    )
                }
            }
            .background(GeometryReader { geo -> Color in
                if geo.frame(in: .global).origin.y > 5 {
                    data.updateJournal(with: 2, and: journals.count)
                }
                return Color.clear
            })
            .padding(.top, offset)
        }
        .clipped()
    }
}

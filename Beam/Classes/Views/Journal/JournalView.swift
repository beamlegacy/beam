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
    var journals: [BeamNote] { journal }
    var offset: CGFloat

    var body: some View {
        ScrollView([.vertical]) {
            VStack {
                ForEach(journals) { note in
                    NoteView(note: note,
                         leadingAlignement: 185,
                         showTitle: true,
                         scrollable: false
                    )
                }
            }
            .padding(.top, offset)
        }
        .clipped()
    }
}

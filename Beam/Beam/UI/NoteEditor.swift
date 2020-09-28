//
//  NoteEditor.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/09/2020.
//

import Foundation
import SwiftUI

struct NoteEditor: View {
    @EnvironmentObject var state: BeamState
    @Binding var note: BeamNote
    var body: some View {
//        ScrollView {
            BeamNoteEditorHost(state, note)
//        }
    }
}

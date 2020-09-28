//
//  BeamNoteEditor.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/09/2020.
//

import Foundation
import AppKit
import SwiftUI
import Combine

struct BeamNoteEditorHost: NSViewRepresentable {
    typealias NSViewType = BeamNoteEditor
    private var editor: BeamNoteEditor
    var state: BeamState
    var note: BeamNote
    private var cancellables = [Cancellable]()
    
    init(_ state: BeamState, _ note: BeamNote) {
        self.state = state
        self.note = note
        
        editor = BeamNoteEditor(state, note)
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        return editor
    }

    func updateNSView(_ nsView: Self.NSViewType, context: Self.Context) {
    }

}

class BeamNoteEditor: NSView {
    var state: BeamState
    var note: BeamNote
    
    init(_ state: BeamState, _ note: BeamNote) {
        self.state = state
        self.note = note
        super.init(frame: NSRect())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

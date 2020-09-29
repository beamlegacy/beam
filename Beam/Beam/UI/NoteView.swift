//
//  NoteView.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/09/2020.
//

import Foundation
import SwiftUI

struct NoteView: View {
    @EnvironmentObject var state: BeamState
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack {
                if let note = state.currentNote {
                    Text("Original search query: \(note.title)")
                    VStack {
                        ForEach(note.visitedSearchResults) { i in
                            Text("visited: \(i.url.absoluteString)")
                        }
                    }
                }
            }
            
        }
    }
}

//
//  Frame.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct Frame<V: View>: View {
    @Environment(\.self) var env
    let content: V
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0).stroke().foregroundColor(.red)
            content
        }
    }
}

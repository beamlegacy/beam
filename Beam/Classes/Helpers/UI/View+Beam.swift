//
//  View+Beam.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/07/2021.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

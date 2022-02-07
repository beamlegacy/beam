//
//  BeamWindowInfo.swift
//  Beam
//
//  Created by Stef Kors on 27/01/2022.
//

import Foundation
import SwiftUI

class BeamWindowInfo: ObservableObject {
    @Published var windowIsResizing = false
    var undraggableWindowRects: [CGRect] = []
    @Published var windowIsMain = true
    @Published var windowFrame = CGRect.zero
}

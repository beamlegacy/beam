//
//  NSButtonCheckboxHelper.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/12/2021.
//

import Foundation

// If you need tu use a NSButton checkbox in a SwiftUI you can use this helper
class NSButtonCheckboxHelper {
    var isOn: Bool = false

    @objc func checkboxClicked() {
        self.isOn.toggle()
  }
}

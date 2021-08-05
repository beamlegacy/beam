//
//  UIElement.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation

//Extension for UIElement class to make accessibility identifiers accessible via Page Objects
protocol UIElement {
    var accessibilityIdentifier: String { get }
}

extension UIElement where Self: RawRepresentable {
    
    var accessibilityIdentifier: RawValue {
        return self.rawValue
    }
}

//
//  Equalable.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.06.2022.
//

import Foundation

protocol Equalable {
    func isEqualTo(_ row: Equalable) -> (Bool, String)
}

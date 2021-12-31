//
//  MouseHandler.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/01/2021.
//

import Foundation

protocol MouseHandler {
    var cursor: NSCursor? { get }
    var description: String { get }
}

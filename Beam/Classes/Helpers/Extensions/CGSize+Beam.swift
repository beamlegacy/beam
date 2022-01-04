//
//  CGSize+Beam.swift
//  Beam
//
//  Created by Stef Kors on 14/12/2021.
//

import Foundation

extension CGSize {
    var aspectRatio: CGFloat {
        self.height / self.width
    }
}

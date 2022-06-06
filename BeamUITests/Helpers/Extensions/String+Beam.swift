//
//  String+Beam.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 26.05.2022.
//

import Foundation

extension String {
    
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
}

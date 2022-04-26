//
//  String+Formatting.swift
//  BeamCore
//
//  Created by Jean-Louis Darmon on 21/04/2022.
//

extension String {
    public func capitalizeFirstChar() -> String {
        self.prefix(1).capitalized + self.dropFirst()
    }
}

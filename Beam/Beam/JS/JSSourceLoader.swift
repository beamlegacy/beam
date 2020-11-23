//
//  JSSourceLoader.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation

func loadJS(from fileName: String) -> String {
    do {
        let path = Bundle.main.path(forResource: fileName, ofType: "js")
        return try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    } catch {
        //
        fatalError("Error, couldnt' load '\(fileName)'")
    }
}

//
//  JSSourceLoader.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation

func loadFile(from fileName: String, fileType: String) -> String {
    do {
        let path = Bundle.main.path(forResource: fileName, ofType: fileType)
        if path == nil {
            fatalError("Could not find '\(fileName).\(fileType)'")
        }
        return try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    } catch (let error) {
        //
        fatalError("Error, could not load '\(fileName)': \(error)")
    }
}

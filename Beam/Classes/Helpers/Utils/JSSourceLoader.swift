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
        return try String(contentsOfFile: path!, encoding: String.Encoding.utf16)
    } catch (let error) {
        //
        fatalError("Error, could not load '\(fileName)': \(error)")
    }
}

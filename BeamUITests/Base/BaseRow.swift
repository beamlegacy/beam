//
//  BaseRow.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 01.06.2022.
//

import Foundation

class BaseRow: Equalable {
    
    func isEqualTo(_ row: Equalable) -> (Bool, String) {
        var failedValues = [String]()
        let currentObject = Mirror(reflecting: self).children
        let externalObject = Mirror(reflecting: row).children
        
        if(currentObject.count != externalObject.count) {
            return (false, "Objects properties number is different")
        }
        
        currentObject.forEach{item in
            
            let itemLabel = item.label
            let external = externalObject.first(where: {$0.label == itemLabel})
            
            let typeName = String(describing: type(of: item.value))
            switch typeName {
            case "Optional<String>":
                let v1 = item.value as? String
                let v2 = external!.value as? String
                if (v1 != v2) {
                    failedValues.append("'\(String(describing: itemLabel))' value:\(String(describing: v1)) is not equal to value:\(String(describing: v2))")
                }
            case "Optional<Int>":
                let v1 = item.value as? Int
                let v2 = external!.value as? Int
                if (v1 != v2) {
                    failedValues.append("'\(String(describing: itemLabel))' value:\(String(describing: v1)) is not equal to value:\(String(describing: v2))")
                }
            case "Optional<Bool>":
                let v1 = item.value as? Bool
                let v2 = external!.value as? Bool
                if (v1 != v2) {
                    failedValues.append("'\(String(describing: itemLabel))' value:\(String(describing: v1)) is not equal to value:\(String(describing: v2))")
                }
            default: break
            }
        }
        return (failedValues.count == 0, failedValues.joined(separator: " || "))
    }
    
    private func getValues(_ value1: Any, _ value2: Any) -> (Any, Any){
        let typeName = String(describing: type(of: value1))
        switch typeName {
        case "Optional<String>":
            return (value1 as! String, value2 as! String)
        case "Optional<Int>":
            return (value1 as! Int, value2 as! Int)
        case "Optional<Bool>":
            return (value1 as! Bool, value2 as! Bool)
        default: break
        }
        return ("\(typeName) is not handled", "")
    }
}

//
//  String+Localization.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/09/2020.
//

import Foundation
import SwiftUI

public extension LocalizedStringKey {
    var stringKey: String {
        let description = "\(self)"
        let components = description.components(separatedBy: "key: \"")
            .map { $0.components(separatedBy: "\",") }

        return components[1][0]
    }
}

public extension String {
    static func localizedString(for key: String,
                                locale: Locale = .current,
                                comment: String = "") -> String {
        let language = locale.languageCode
        if let path = Bundle.main.path(forResource: language, ofType: "lproj") {
            let bundle = Bundle(path: path)!
            let localizedString = NSLocalizedString(key, bundle: bundle, comment: comment)

            return localizedString
        }

        return key
    }

    func localizedStringWith(comment: String, _ args: CVarArg) -> String {
        return String.localizedStringWithFormat(NSLocalizedString(self, comment: comment), args)
    }
}

public extension LocalizedStringKey {
    func stringValue(locale: Locale = .current) -> String {
        return .localizedString(for: self.stringKey, locale: locale)
    }
}

public func loc(_ textToTranslate: String, comment: String = "") -> String {
    return String.localizedString(for: textToTranslate, comment: comment)
}

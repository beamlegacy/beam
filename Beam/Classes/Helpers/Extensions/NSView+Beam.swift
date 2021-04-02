//
//  NSView+Beam.swift
//  Beam
//
//  Created by Sebastien Metrot on 25/09/2020.
//

import Foundation
import AppKit

public extension NSView {
    @discardableResult func visitSubViews(_ predicate: @escaping (NSView) -> Bool) -> Bool {
        for c in subviews {
            if !predicate(c) {
                return false
            }
            if !c.visitSubViews(predicate) {
                return false
            }
        }
        return true
    }

    func subviewsWith<ViewType>(type: ViewType.Type) -> [ViewType] {
        var views = [ViewType]()
        visitSubViews { view in
            if let v = view as? ViewType {
                views.append(v)
            }
            return true
        }
        return views
    }

    var isDarkMode: Bool {
       if #available(OSX 10.14, *) {
           if effectiveAppearance.name == .darkAqua {
               return true
           }
       }
       return false
   }

    func addSubviewWithConstraintsOnEachSide(subView: NSView) {
        self.addSubview(subView)
        subView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            subView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            subView.topAnchor.constraint(equalTo: self.topAnchor),
            subView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}

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
        effectiveAppearance.name == .darkAqua
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


// Basic code that comes handy to debug system frameworks. DON'T COMMIT THAT CODE ACTIVATED!
#if DEBUG
extension NSView {
    static let classInit: Void = {
       guard let originalMethod = class_getInstanceMethod(NSView.self, #selector(invalidateIntrinsicContentSize)),
             let swizzledMethod = class_getInstanceMethod(NSView.self, #selector(swizzled_invalidateIntrinsicContentSize))
       else { return }
       //method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func swizzled_invalidateIntrinsicContentSize() {
        swizzled_invalidateIntrinsicContentSize()
        print("invalidateIntrinsicContentSize \(self)")
    }
}
// Make sure to call `UIView.classInit` somewhere early, e.g. in the app delegate.
#endif

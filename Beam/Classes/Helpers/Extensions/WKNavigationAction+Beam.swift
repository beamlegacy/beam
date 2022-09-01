//
//  WKNavigationAction+Beam.swift
//  Beam
//
//  Created by Remi Santos on 01/09/2022.
//

import Foundation
import WebKit

extension WKNavigationAction {

    /// Utility to determine if the Command Key was used during a navigation action
    ///
    /// The original `WKNavigationAction.modifierFlags` can sometimes be incorrect so we're checking current NSEvent too.
    /// - Parameter action: The Navigation Action
    /// - Returns: true if Command was used
    var isNavigationWithCommandKey: Bool {
        self.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
    }

    var isNavigationWithMiddleMouseDown: Bool {
        self.buttonNumber == 4
    }

    var shouldBePerformedInBackground: Bool {
        isNavigationWithCommandKey || isNavigationWithMiddleMouseDown
    }

}

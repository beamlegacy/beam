import SwiftUI

// Got from https://stackoverflow.com/questions/57518852/swiftui-picker-onchange-or-equivalent
// Allows to have callbacks when Picker is selected by a user

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        return Binding(
            get: { self.wrappedValue },
            set: { selection in
                self.wrappedValue = selection
                handler(selection)
        })
    }
}

//
//  OptionSelector.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/04/2021.
//

import SwiftUI

struct OptionSelector<T>: View where T: CaseIterable, T: CustomStringConvertible, T: Equatable {
    @Binding var value: T
    let options = Array(T.allCases)

    var body: some View {
        HStack {
            ForEach(options.indices, id: \.self) { idx in
                if idx != 0 {
                    Separator(horizontal: false)
                }
                Button(action: { self.value = options[idx] }, label: {
                    Text("\(options[idx].description)")
                        .fontWeight(options[idx] == value ? .bold : .regular)
                })
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct OptionSelector_Previews: PreviewProvider {
    enum Test: String, CaseIterable, CustomStringConvertible {
        var description: String {
            rawValue
        }

        case one
        case two
    }
    static var previews: some View {
        let value = Test.one
        OptionSelector(value: .constant(value))
    }
}

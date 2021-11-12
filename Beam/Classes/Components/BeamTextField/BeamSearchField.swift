//
//  BeamSearchField.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 26/05/2021.
//

import Foundation
import SwiftUI

struct BeamSearchField: View {
    @Binding var searchStr: String
    @Binding var isEditing: Bool

    var placeholderStr: String
    var font: NSFont
    var textColor: NSColor
    var placeholderColor: NSColor
    var onEscape: (() -> Void)?

    @State var xMarkIsHovered: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(isEditing ? Color.blue.opacity(0.7) : Color.gray.opacity(0.1), lineWidth: isEditing ? 3 : 1.5)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                )
                HStack {
                    Icon(name: "field-search", size: 16, color: BeamColor.Generic.placeholder.swiftUI)
                        .frame(width: 16)
                        .opacity(0.8)
                        .padding(.leading, 6.5)
                    BeamTextField(text: $searchStr,
                                  isEditing: $isEditing,
                                  placeholder: placeholderStr,
                                  font: font,
                                  textColor: textColor,
                                  placeholderColor: placeholderColor,
                                  onEscape: onEscape)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                    if !searchStr.isEmpty {
                        Button(action: {
                                searchStr = ""
                        }, label: {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                                .padding(.trailing, 6.5)
                                .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
                        })
                        .buttonStyle(PlainButtonStyle())
                        .opacity(xMarkIsHovered ? 1 : 0.6)
                        .onHover(perform: { hovering in
                            xMarkIsHovered = hovering
                        })
                    }
                }.frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

struct BeamSearchField_Previews: PreviewProvider {
    static var previews: some View {
        BeamSearchField(searchStr: .constant("hey"), isEditing: .constant(false), placeholderStr: "Search", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor)
            .frame(width: 300, height: 40, alignment: .center)
            .padding()
    }
}

//
//  SymbolView.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/10/2020.
//

import Foundation
import AppKit
import SwiftUI

#if false
struct Symbol: NSViewRepresentable {
    var name: String
    var size: Float = 16

    func makeNSView(context: Context) -> SymbolView {
        do {
            return try SymbolView(name, size: CGFloat(size))
        } catch {
            fatalError()
        }
    }

    func updateNSView(_ nsView: SymbolView, context: Context) {
    }

    typealias NSViewType = SymbolView

//    var body: some View {
//        Text(name).font(.system(size: CGFloat(size))).frame(height: CGFloat(size), alignment: .center)
//    }
}
#endif

class SymbolView: NSView {
    private var font: NSFont
    private var symbol: NSMutableAttributedString
    private var size: CGFloat

    enum SymbolError: Error {
        case bundlePathNotFound
        case fontFileNotFound(URL)
    }

    init(_ symbol: String, size: CGFloat) throws {
        self.symbol = symbol.attributed
        self.size = size

        let bundle = Bundle.main
        guard let resourcePath = bundle.resourcePath else {
            print("unable to find resourcePath")
            throw SymbolError.bundlePathNotFound
        }
        let fontURL = URL(fileURLWithPath: resourcePath + "/SFSymbolsFallback.ttf")
        // swiftlint:disable:next force_cast
        let fd = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor]
        let options = CTFontOptions()
        font = CTFontCreateWithFontDescriptorAndOptions(fd[0], size, nil, options)
        print("symbol font: \(font)")

        super.init(frame: NSRect())

        self.symbol.addAttribute(.font, value: font, range: self.symbol.wholeRange)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var intrinsicContentSize: NSSize {
        return NSSize(width: size, height: size)
    }

    public override func draw(_ dirtyRect: NSRect) {
        symbol.draw(at: NSPoint())
    }
}

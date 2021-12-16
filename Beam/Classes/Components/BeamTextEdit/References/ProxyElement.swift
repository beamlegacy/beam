//
//  ProxyElement.swift
//  Beam
//
//  Created by Sebastien Metrot on 12/05/2021.
//

import Foundation
import BeamCore
import Combine

class ProxyElement: BeamElement {
    var proxy: BeamElement
    override public var isProxy: Bool { true }

    override var text: BeamText {
        didSet {
            guard !updating else { return }
            proxy.text = text
        }
    }

    override var kind: ElementKind {
        didSet {
            guard !updating else { return }
            proxy.kind = kind
        }
    }

    override var childrenFormat: ElementChildrenFormat {
        didSet {
            guard !updating else { return }
            proxy.childrenFormat = childrenFormat
        }
    }

    override var updateDate: Date {
        didSet {
            guard !updating else { return }
            proxy.updateDate = updateDate
        }
    }

    override var note: BeamNote? {
        return proxy.note
    }

    var updating = false
    var scope = Set<AnyCancellable>()

    init(for element: BeamElement) {
        self.proxy = element
        super.init(proxy.text)

        proxy.$children
            .sink { [unowned self] newChildren in
                updating = true; defer { updating = false }
                self.updateProxyChildren(newChildren)
            }.store(in: &scope)

        proxy.$text
            .sink { [unowned self] newValue in
                updating = true; defer { updating = false }
                text = newValue
            }.store(in: &scope)

        proxy.$kind
            .sink { [unowned self] newValue in
                updating = true; defer { updating = false }
                kind = newValue
            }.store(in: &scope)

        proxy.$childrenFormat
            .sink { [unowned self] newValue in
                updating = true; defer { updating = false }
                childrenFormat = newValue
            }.store(in: &scope)

        proxy.$updateDate
            .sink { [unowned self] newValue in
                updating = true; defer { updating = false }
                updateDate = newValue
            }.store(in: &scope)
    }

    func updateProxyChildren(_ newChildren: [BeamElement]) {
        self.children = newChildren
    }

    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

}

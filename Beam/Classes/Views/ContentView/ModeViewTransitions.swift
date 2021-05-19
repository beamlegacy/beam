//
//  ModeViewTransitions.swift
//  Beam
//
//  Created by Remi Santos on 18/05/2021.
//

import SwiftUI
import Combine

// MARK: - Transition Model
/**
    This model helps enable/disabling transition depending on the current vs previous mode
 */
class ModeTransitionModel {
    var state: BeamState? {
        didSet {
            cancellables.removeAll()
            guard let newState = state else { return }
            newState.$mode
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                .sink { [weak self] newMode in
                    guard let self = self else { return }
                    self.previousMode = newMode
                }.store(in: &cancellables)
        }
    }
    private var cancellables = [AnyCancellable]()

    private(set) var previousMode: Mode?
    var currentMode: Mode {
        state?.mode ?? .today
    }
}

// MARK: - Web Mode Content Transition
private struct WebContentTransitionModifier: ViewModifier {
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var delay: Double = 0.0
    var opacityDelay: Double = 0.0
    var offset: CGSize = .zero
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offsetEffect(offset)
            .animation(Animation.easeInOut(duration: 0.2).delay(delay))
            .opacity(opacity)
            .animation(Animation.easeInOut(duration: 0.1).delay(opacityDelay))
    }
}

extension AnyTransition {
    private static var webContentInTransition: AnyTransition {
        .modifier(
            active: WebContentTransitionModifier(opacity: 0.0, scale: 0.98, offset: CGSize(width: 0, height: 20)),
            identity: WebContentTransitionModifier(delay: 0.05, opacityDelay: 0.05)
        )
    }
    private static var webContentOutTransition: AnyTransition {
        .modifier(
            active: WebContentTransitionModifier(opacity: 0.0, scale: 0.98, delay: 0.0, opacityDelay: 0.1, offset: CGSize(width: 0, height: 20)),
            identity: WebContentTransitionModifier()
        )
    }
    static var webContentTransition: AnyTransition {
        .asymmetric(insertion: .webContentInTransition, removal: .webContentOutTransition)
    }
}

// MARK: - Note Mode Content Transition
private struct NoteContentTransitionModifier: ViewModifier {
    var transitionModel: ModeTransitionModel
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
    var enableTransition: Bool {
        // enable only between note<>web
        transitionModel.currentMode == .web || transitionModel.previousMode == .web
    }
    var delay: Double {
        // animation delayed when transitioning from web
        transitionModel.previousMode == .web ? 0.1 : 0.0
    }
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offsetEffect(offset)
            .animation(enableTransition ? Animation.easeInOut(duration: 0.2).delay(delay) : nil)
    }
}

extension AnyTransition {

    static func noteContentTransition(transitionModel tm: ModeTransitionModel) -> AnyTransition {
        .modifier(
            active: NoteContentTransitionModifier(transitionModel: tm, scale: 0.98, offset: CGSize(width: 0, height: 7)),
            identity: NoteContentTransitionModifier(transitionModel: tm)
        )
    }
}

// MARK: - Custom Modifiers
private extension View {
    // View.offset is not a geometry transform like .scaleEffet or .rotationEffect. This is.
    func offsetEffect(x: CGFloat, y: CGFloat) -> some View {
        modifier(OffsetGeometryEffect(offset: CGSize(width: x, height: y)))
    }

    func offsetEffect(_ offset: CGSize) -> some View {
        modifier(OffsetGeometryEffect(offset: offset))
    }
}

private struct OffsetGeometryEffect: GeometryEffect {
    var offset: CGSize

    var animatableData: CGSize.AnimatableData {
        get { CGSize.AnimatableData(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: offset.width, y: offset.height))
    }
}

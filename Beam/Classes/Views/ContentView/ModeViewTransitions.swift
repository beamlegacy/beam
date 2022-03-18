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
                    guard let self = self, self.previousMode != newMode else { return }
                    self.previousMode = newMode
                }.store(in: &cancellables)
            newState.$mode
                .sink { [weak self] newMode in
                    guard let self = self, self.previousMode != newMode else { return }
                    guard self.previousMode == .web || newMode == .web else { return }
                    self.transitionDelayWorkItem?.cancel()
                    self.isTransitioning = true
                    let workItem = DispatchWorkItem { [weak self] in
                        self?.isTransitioning = false
                    }
                    self.transitionDelayWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.transitionDelay), execute: workItem)
                }.store(in: &cancellables)
        }
    }
    private var transitionDelayWorkItem: DispatchWorkItem?
    private var transitionDelay: Int = 300
    private var cancellables = [AnyCancellable]()

    private(set) var previousMode: Mode?
    var currentMode: Mode {
        state?.mode ?? .today
    }
    private(set) var isTransitioning: Bool = false
}

// MARK: - Web Mode Content Transition
private struct WebContentTransitionModifier: ViewModifier {
    var isResizing: Bool
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var delay: Double = 0.0
    var opacityDelay: Double = 0.0
    var offset: CGSize = .zero
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offsetEffect(offset)
            .animation(isResizing ? nil : Animation.easeInOut(duration: 0.1).delay(delay))
            .opacity(opacity)
            .animation(isResizing ? nil : Animation.easeInOut(duration: 0.07).delay(opacityDelay))
    }
}

extension AnyTransition {
    private static func webContentInTransition(_ isResizing: Bool) -> AnyTransition {
        .modifier(
            active: WebContentTransitionModifier(isResizing: isResizing, opacity: 0.0, scale: 0.98, offset: CGSize(width: 0, height: 20)),
            identity: WebContentTransitionModifier(isResizing: isResizing, delay: 0.03, opacityDelay: 0.03)
        )
    }
    private static func webContentOutTransition(_ isResizing: Bool) -> AnyTransition {
        .modifier(
            active: WebContentTransitionModifier(isResizing: isResizing, opacity: 0.0, scale: 0.98, delay: 0.0, opacityDelay: 0.07, offset: CGSize(width: 0, height: 20)),
            identity: WebContentTransitionModifier(isResizing: isResizing)
        )
    }
    static func webContentTransition(_ isResizing: Bool) -> AnyTransition {
        .asymmetric(insertion: .webContentInTransition(isResizing), removal: .webContentOutTransition(isResizing))
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
        transitionModel.previousMode == .web ? 0.07 : 0.0
    }
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offsetEffect(offset)
            .animation(enableTransition ? Animation.easeInOut(duration: 0.1).delay(delay) : nil)
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

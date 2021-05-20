//
//  ToastView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 03/05/2021.
//

import SwiftUI

struct ToastView<Content: View>: View {
    @Environment(\.toastStyle) var style: AnyToastStyle

    @Binding var isPresented: Bool

    var delay: TimeInterval
    var content: Content

    init(isPresented: Binding<Bool>, delay: TimeInterval = 0.8, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        ZStack {
            VStack {
                if isPresented {
                    style.makeToast(configuration: ToastStyleContentConfiguration(alignment: .bottomTrailing, content: AnyView(self.content)), isPresented: $isPresented)
                        .animation(.easeInOut)
                        .onTapGesture {
                            withAnimation {
                                self.isPresented = false
                            }
                        }
                        .onAppear(perform: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                withAnimation {
                                    self.isPresented = false
                                }
                            }
                        })
                }
            }
        }
    }
}

// MARK: - Style Protocol

struct ToastStyleContentConfiguration {
    let alignment: Alignment
    let content: AnyView
}

protocol ToastStyle {
    associatedtype Toast: View
    typealias ToastContentConfiguration = ToastStyleContentConfiguration

    func makeToast(configuration: ToastStyleContentConfiguration, isPresented: Binding<Bool>) -> Toast
}

extension ToastStyle {
    func anyMakeToast(configuration: ToastStyleContentConfiguration, isPresented: Binding<Bool>) -> AnyView {
        AnyView(makeToast(configuration: configuration, isPresented: isPresented))
    }
}

public struct AnyToastStyle: ToastStyle {
    private let _makeToast: (ToastStyleContentConfiguration, Binding<Bool>) -> AnyView

    init<Style: ToastStyle>(_ style: Style) {
        self._makeToast = style.anyMakeToast(configuration:isPresented:)
    }

    func makeToast(configuration: ToastStyleContentConfiguration, isPresented: Binding<Bool>) -> AnyView {
        return self._makeToast(configuration, isPresented)
    }
}

// MARK: - Toast Styles

struct DefaultToastStyle: ToastStyle {
    func makeToast(configuration: ToastStyleContentConfiguration, isPresented: Binding<Bool>) -> some View {
        ToastContent(height: 42, cornerRadius: 6, shadowRadius: 16, shadowX: 0, shadowY: 6, configuration: configuration)
    }
}

struct BottomTraillingToastStyle: ToastStyle {
    func makeToast(configuration: ToastStyleContentConfiguration, isPresented: Binding<Bool>) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ToastContent(height: 42, cornerRadius: 6, shadowRadius: 16, shadowX: 0, shadowY: 6, configuration: configuration)
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
            }
        }
    }
}

// MARK: - ToastContentView

struct ToastContent: View {
    var height: CGFloat
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var shadowX: CGFloat
    var shadowY: CGFloat
    var configuration: ToastStyleContentConfiguration

    var body: some View {
        configuration.content
            .background(BeamColor.Generic.background.swiftUI)
            .frame(height: height, alignment: .center)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.17), radius: shadowRadius, x: shadowX, y: shadowY)
            .zIndex(1001)
    }
}

// MARK: - Environment Key

struct ToastStyleKey: EnvironmentKey {
    public static let defaultValue: AnyToastStyle = AnyToastStyle(DefaultToastStyle())
    public static let bottomTraillingvalue: AnyToastStyle = AnyToastStyle(BottomTraillingToastStyle())
}

extension EnvironmentValues {
    var toastStyle: AnyToastStyle {
        get {
            return self[ToastStyleKey.self]
        }
        set {
            self[ToastStyleKey.self] = newValue
        }
    }
}

// MARK: - View Protocol

extension View {
    func toast<ToastBody: View>(isPresented: Binding<Bool>, @ViewBuilder toastBody: () -> ToastBody) -> some View {
        ToastView(isPresented: isPresented, content: toastBody)
    }

    func toastStyle<Style: ToastStyle>(_ style: Style) -> some View {
        self.environment(\.toastStyle, AnyToastStyle(style))
    }
}

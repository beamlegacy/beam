//
//  OnboardingCalendarView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 10/10/2022.
//

import SwiftUI
import BeamCore
struct OnboardingCalendarView: View {
    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback
    var calendarManager = BeamData.shared.calendarManager

    var body: some View {
        VStack {
            Image("preferences-account_calendars")
                .resizable()
                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                .frame(width: 52, height: 55)
            OnboardingView.TitleAndSubtitle(title: "Connect your Calendar", subtitle: "Take meeting notes and join video calls.")
            ActionableButton(text: loc("Connect macOS Calendar"), defaultState: .normal, variant: calendarVariant(service: .appleCalendar), minWidth: 260, height: 34, cornerRadius: 6, invertBlendMode: false) {
                connectCalendar(service: .appleCalendar)
            }
            ActionableButton(text: loc("Connect Google Calendar"), defaultState: .normal, variant: calendarVariant(service: .googleCalendar), minWidth: 260, height: 34, cornerRadius: 6, invertBlendMode: false) {
                connectCalendar(service: .googleCalendar)
            }
        }.onAppear {
            updateActions()
        }.background(KeyEventHandlingView(handledKeyCodes: [.enter, .space], firstResponder: true, onKeyDown: { event in
            finish(nil)
        }))
    }

    private func calendarVariant(service: CalendarServices) -> ActionableButtonVariant {
        var calendarVariant = ActionableButtonVariant.ghost.style
        calendarVariant.icon = .init(name: service == .appleCalendar ? "onboarding-account_macOScalendar" : "onboarding-google_logo", size: 16, alignment: .center, isTemplate: false)
        calendarVariant.foregroundColor = ActionableButtonState.Palette(normal: BeamColor.Niobium,
                                                                   hovered: BeamColor.Niobium,
                                                                   clicked: BeamColor.Niobium,
                                                                   disabled: BeamColor.Niobium)
        calendarVariant.backgroundColor = ActionableButtonState.Palette(normal: BeamColor.Generic.background.alpha(0),
                                                                  hovered: BeamColor.combining(lightColor: .Nero, lightAlpha: 1, darkColor: .Mercury, darkAlpha: 1),
                                                                  clicked: BeamColor.combining(lightColor: .Mercury, lightAlpha: 1, darkColor: .AlphaGray, darkAlpha: 1),
                                                                  disabled: BeamColor.Generic.background.alpha(0))
        calendarVariant.backgroundColor.stroke = ActionableButtonState.StrokePalette(normal: BeamColor.combining(lightColor: .Mercury, lightAlpha: 1, darkColor: .AlphaGray, darkAlpha: 1),
                                                                                   hovered: BeamColor.combining(lightColor: .Mercury, lightAlpha: 1, darkColor: .AlphaGray, darkAlpha: 1),
                                                                                   clicked: BeamColor.combining(lightColor: .Mercury, lightAlpha: 1, darkColor: .AlphaGray, darkAlpha: 1),
                                                                                   disabled: .ActionableButtonBeam.strokeDisabled, lineWidth: 1.5)
        calendarVariant.textAlignment = .center
        return .custom(calendarVariant)
    }

    private func connectCalendar(service: CalendarServices) {
        calendarManager.requestAccess(from: service) { connected in
            if connected { calendarManager.updated = true }
            finish(nil)
        }
    }

    private let skipActionId = "skip_action"
    private var ghostSkipVariant: ActionableButtonVariant {
        var ghostSkipVariant = ActionableButtonVariant.ghost.style
        ghostSkipVariant.icon = nil
        ghostSkipVariant.textAlignment = .center
        return .custom(ghostSkipVariant)

    }

    private func updateActions() {
        actions = [.init(id: skipActionId, title: "Skip", enabled: true, customVariant: ghostSkipVariant, customWidth: 67, alignment: .center)]
    }
}

struct OnboardingCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingCalendarView(actions: .constant([])) { _ in }
    }
}

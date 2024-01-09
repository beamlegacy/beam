import SwiftUI
import BeamCore
import OAuthSwift
import Combine

class CalendarsViewModel: ObservableObject {
    @ObservedObject var calendarManager: CalendarManager
    @Published var accountsCalendar: [AccountCalendar] = []

    private var scope = Set<AnyCancellable>()

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        calendarManager.$connectedSources.sink { [weak self] sources in
            guard let self = self, !sources.isEmpty else {
                self?.accountsCalendar.removeAll()
                return
            }
            for source in sources {
                BeamData.shared.calendarManager.getInformation(for: source) { accountCalendar in
                    if !self.accountsCalendar.contains(where: { $0.sourceId == source.id }) {
                        self.accountsCalendar.append(accountCalendar)
                    }
                }
            }
        }.store(in: &scope)
    }
}

/// The main view of “Accounts” preference pane.
struct CalendarsView: View {
    @State private var enableLogging = true
    @State private var errorMessage: Error!
    @State private var loading = false

    @ObservedObject var viewModel: CalendarsViewModel

    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            calendarSection
        }
    }

    private var calendarSection: Settings.Row {
        Settings.Row(hasDivider: false) {
            Text("Calendars & Contacts:")
        } content: {
            CalendarContent(viewModel: viewModel)
        }
    }
}

struct CalendarsView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarsView(viewModel: CalendarsViewModel(calendarManager: BeamData.shared.calendarManager))
    }
}

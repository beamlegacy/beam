import SwiftUI
import Combine
import BeamCore

struct DatabaseDetail: View {
    @ObservedObject var database: Database
    let databaseManager = DatabaseManager()
    @State private var refreshing = false

    var body: some View {
        ScrollView {
            HStack(alignment: VerticalAlignment.center, spacing: 10.0) {
                RefreshButton
                SoftDeleteButton
                DeleteButton
                Spacer()
            }.padding()

            VStack {
                Text(database.title)
            }
        }.onAppear {
            refresh()
        }
    }
    private func refresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }

        do {
            try databaseManager.refresh(DatabaseStruct(database: database)) { _ in
                DispatchQueue.main.async {
                    timer.invalidate()
                    refreshing = false
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .document)
        }
    }

    private func delete() {
        databaseManager.delete(id: database.id) { _ in }
    }

    private func softDelete() {
        var dbStruct = DatabaseStruct(database: database)
        dbStruct.deletedAt = BeamDate.now

        databaseManager.save(dbStruct, completion: { _ in
        })
    }

    private var RefreshButton: some View {
        Button(action: {
            refresh()
        }, label: {
            Text(refreshing ? "Refreshing" : "Refresh").frame(minWidth: 100)
        }).disabled(refreshing)
    }

    private var DeleteButton: some View {
        Button(action: {
            delete()
        }, label: {
            Text("Delete").frame(minWidth: 100)
        })
    }

    private var SoftDeleteButton: some View {
        Button(action: {
            softDelete()
        }, label: {
            Text("Soft Delete").frame(minWidth: 100)
        })
    }

    static private let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .long
        return formatter
    }()
}

struct DatabaseDetail_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext
        let database: Database = Database(context: context)
        database.title = String.randomTitle()

        return DatabaseDetail(database: database).background(Color.white)
    }
}

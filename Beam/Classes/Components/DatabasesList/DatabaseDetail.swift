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
                SoftUnDeleteButton
                DeleteButton
                MoveOrphanButton
                Spacer()
            }.padding()

            HStack {
                VStack {
                    HStack {
                        Text("ID:").bold()
                        Text(database.uuidString)
                        Spacer()
                    }

                    HStack {
                        Text("Beam Object Checksum:").bold()
                        Text(database.beam_object_previous_checksum ?? "-")
                        Spacer()
                    }

                    HStack {
                        Text("Title:").bold()
                        Text(database.title)
                        Spacer()
                    }

                    HStack {
                        Text("Created At:").bold()
                        Text("\(database.created_at, formatter: Self.dateFormat)")
                        Spacer()
                    }
                    HStack {
                        Text("Updated At:").bold()
                        Text("\(database.updated_at, formatter: Self.dateFormat)")
                        Spacer()
                    }
                    if let deleted_at = database.deleted_at {
                        HStack {
                            Text("Deleted At:").bold()
                            Text("\(deleted_at, formatter: Self.dateFormat)")
                            Spacer()
                        }
                    }
                }.background(Color.white).padding()
                Spacer()
            }
            Spacer()
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
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }
        databaseManager.delete(DatabaseStruct(database: database)) { _ in
            timer.invalidate()
            refreshing = false
        }
    }

    private func softDelete() {
        var dbStruct = DatabaseStruct(database: database)
        dbStruct.deletedAt = BeamDate.now
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }
        databaseManager.save(dbStruct, completion: { _ in
            timer.invalidate()
            refreshing = false
        })
    }

    private func softUnDelete() {
        var dbStruct = DatabaseStruct(database: database)
        dbStruct.deletedAt = nil
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            refreshing = true
        }
        databaseManager.save(dbStruct, completion: { _ in
            timer.invalidate()
            refreshing = false
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
        }).disabled(refreshing)
    }

    private var MoveOrphanButton: some View {
        Button(action: {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                refreshing = true
            }

            DocumentManager().moveAllOrphanNotes(databaseId: database.id) { _ in
                timer.invalidate()
                refreshing = false
            }
        }, label: {
            Text("Move Orphan Notes").frame(minWidth: 100)
        }).disabled(refreshing)
    }

    private var SoftDeleteButton: some View {
        Button(action: {
            softDelete()
        }, label: {
            Text("Soft Delete").frame(minWidth: 100)
        }).disabled(refreshing)
    }

    private var SoftUnDeleteButton: some View {
        Button(action: {
            softUnDelete()
        }, label: {
            Text("Recover").frame(minWidth: 100)
        }).disabled(refreshing)
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

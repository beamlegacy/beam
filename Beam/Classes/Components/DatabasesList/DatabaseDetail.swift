import SwiftUI
import Combine

struct DatabaseDetail: View {
    @ObservedObject var database: Database
    let databaseManager = DatabaseManager()

    var body: some View {
        ScrollView {
            HStack(alignment: VerticalAlignment.center, spacing: 10.0) {
                SoftDeleteButton
                DeleteButton
                Spacer()
            }.padding()

            VStack {
                Text(database.title)
            }
        }
    }

    private func delete() {
        let dbStruct = DatabaseStruct(database: database)
        databaseManager.delete(dbStruct, completion: nil)
    }

    private func softDelete() {
        var dbStruct = DatabaseStruct(database: database)
        dbStruct.deletedAt = BeamDate.now

        databaseManager.save(dbStruct, completion: { _ in
        })
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

import SwiftUI
import Combine

struct DatabaseDetail: View {
    @ObservedObject var database: Database

    var body: some View {
        Text(database.title)
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

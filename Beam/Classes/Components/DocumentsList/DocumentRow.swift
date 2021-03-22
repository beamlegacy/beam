import SwiftUI

struct DocumentRow: View {
    @ObservedObject var document: Document

    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        VStack {
            HStack {
                Text(document.title)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.callout)

                Spacer()
            }

            HStack {
                Text("\(document.updated_at, formatter: Self.taskDateFormat)").font(.footnote)
                if document.isDeleted || document.deleted_at != nil {
                    Text("deleted").font(.footnote)
                }
                Spacer()
            }
        }.padding(.bottom).padding(.top)
    }
}

struct DocumentRow_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext

        return Group {
            DocumentRow(document: Document.fetchWithTitle(context, "outline")!)
            DocumentRow(document: Document.fetchFirst(context: context)!)
        }.previewLayout(.fixed(width: 300, height: 70))
    }
}

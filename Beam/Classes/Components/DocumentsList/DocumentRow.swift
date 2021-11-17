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
            if document.managedObjectContext != nil {
                HStack {
                    Text("\(document.database()?.title ?? "") > \(document.title)")
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

                Spacer()
            }
        }
        .padding(.vertical)
    }
}

struct DocumentRow_Previews: PreviewProvider {
    static var previews: some View {
        //swiftlint:disable force_try
        let documentManager = DocumentManager()
        let outline = try! documentManager.fetchWithTitle("outline")!
        let document = try! documentManager.fetchFirst()!
        return Group {
            DocumentRow(document: outline)
            DocumentRow(document: document)
        }.previewLayout(.fixed(width: 300, height: 70))
    }
}

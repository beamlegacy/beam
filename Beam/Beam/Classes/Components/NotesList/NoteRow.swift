import SwiftUI

struct NoteRow: View {
    @ObservedObject var note: Note

    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        VStack {
            HStack {
                Text(note.title)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.callout)

                Spacer()

                if let count = note.bullets?.count, count > 0 {
                    Text("\(count)")
                        .padding(.horizontal, 5)
                        .background(Color.blue)
                        .foregroundColor(Color.white)
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text("\(note.updated_at, formatter: Self.taskDateFormat)").font(.footnote)
                Spacer()
            }
        }.padding(.bottom).padding(.top)
    }
}

struct NoteRow_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext

        return Group {
            NoteRow(note: Note.fetchWithTitle(context, "outline")!)
            NoteRow(note: Note.fetchFirst(context: context)!)
        }.previewLayout(.fixed(width: 300, height: 70))
    }
}

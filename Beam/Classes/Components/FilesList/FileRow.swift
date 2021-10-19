import SwiftUI

struct FileRow: View {
    var file: BeamFileRecord

    static let taskDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        VStack {
                HStack {
                    Text("\(file.name)")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout)

                    Spacer()
                }

                HStack {
                    Text("\(file.updatedAt, formatter: Self.taskDateFormat)").font(.footnote)
                    if file.deletedAt != nil {
                        Text("deleted").font(.footnote)
                    }
                    Spacer()
                }

                Spacer()
        }
        .padding(.vertical)
    }
}

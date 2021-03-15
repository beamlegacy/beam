import SwiftUI

struct DocumentDetail: View {
    @State private var refreshing = false

    let document: Document
    let documentManager = DocumentManager()

    var body: some View {
        ScrollView {
            RefreshButton.padding()

            HStack {
                VStack {
                    HStack {
                        Text("ID:").bold()
                        Text(document.uuidString)
                        Spacer()
                    }
                    HStack {
                        Text("Title:").bold()
                        Text(document.title)
                        Spacer()
                    }
                    HStack {
                        Text("Created At:").bold()
                        Text("\(document.created_at, formatter: Self.dateFormat)")
                        Spacer()
                    }
                    HStack {
                        Text("Updated At:").bold()
                        Text("\(document.updated_at, formatter: Self.dateFormat)")
                        Spacer()
                    }
                    if let deleted_at = document.deleted_at {
                        HStack {
                            Text("Deleted At:").bold()
                            Text("\(deleted_at, formatter: Self.dateFormat)")
                            Spacer()
                        }
                    }
                    Divider()

                    Spacer()

                    HStack(alignment: .top) {
                        VStack(alignment: HorizontalAlignment.leading) {
                            Text(document.data?.MD5 ?? "No MD5")
                                .font(.caption)
                                .fontWeight(.light)
                                .background(Color.white)
                            Text(document.data?.asString ?? "No data")
                                .font(.caption)
                                .fontWeight(.light)
                                .background(Color.white)
                        }
                        Spacer()

                        VStack(alignment: HorizontalAlignment.leading) {
                            Text(document.beam_api_checksum ?? "No MD5")
                                .font(.caption)
                                .fontWeight(.light)
                                .background(Color.white)
                            Text(document.beam_api_data?.asString ?? "No ancestor data")
                                .font(.caption)
                                .fontWeight(.light)
                                .background(Color.white)
                        }
                        Spacer()
                    }

                    Divider()
                }.background(Color.white).padding()
                Spacer()
            }
            Spacer()
        }.onAppear {
            refresh()
        }
    }

    private func refresh() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            refreshing = true
        }

        documentManager.refreshDocument(DocumentStruct(document: document)) { _ in
            DispatchQueue.main.async {
                timer.invalidate()
                refreshing = false
            }
        }
    }

    private var RefreshButton: some View {
        Button(action: {
            refresh()
        }, label: {
            if refreshing {
                Text("Refreshing").frame(minWidth: 100)
            } else {
                Text("Refresh").frame(minWidth: 100)
            }
        }).disabled(refreshing)
    }

    static private let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .long
        return formatter
    }()
}

struct DocumentDetail_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext
        let document = Document.fetchFirst(context: context)!

        return DocumentDetail(document: document).background(Color.white)
    }
}

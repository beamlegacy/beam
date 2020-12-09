import SwiftUI

struct NoteDetail: View {
    var note: Note

    var body: some View {
        VStack {
            HStack {
                VStack {
                    ScrollView {
                        Text(note.fullContent())
                            .background(Color.white)
                    }.background(Color.white)
                    Spacer()
                }
                Spacer()

                VStack {
                    if let attributedString = note.attributedString() {
                        TextView(text: .constant(attributedString))
                    }
                    Spacer()
                }
                Spacer()
            }
            Spacer()
        }.padding()
    }
}

struct NoteDetail_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.mainContext
        let note = Note.fetchFirst(context: context)!

        return NoteDetail(note: note).background(Color.white)
    }
}

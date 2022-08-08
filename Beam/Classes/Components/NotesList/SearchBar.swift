import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            TextField("Search", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Spacer(minLength: 0)

            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                }, label: {
                    Text("Cancel")
                })
                .padding(.trailing, BeamSpacing._100)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
        .onTapGesture {
            self.isEditing = true
        }
    }

    public struct CustomTFStyle: TextFieldStyle {
        public func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding(7)
                .padding(.horizontal, 15)
                .cornerRadius(8)
                .foregroundColor(.black)
        }
    }
}

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        SearchBar(text: .constant(""))
    }
}

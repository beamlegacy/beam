import SwiftUI

struct PointAndShootCardConfirmationBox: View {
    @EnvironmentObject var state: BeamState

    static let size = CGSize(width: 170, height: 42)

    var group: PointAndShoot.ShootGroup
    var isText = true
    @State var isVisible = false

    private var iconName: String {
        return isText ? "collect-text" : "collect-generic"
    }
    private var prefixText: String {
        return group.numberOfElements == 1 ? "Added to " : "\(group.numberOfElements) Added to "
    }
    var body: some View {
        FormatterViewBackground {
            HStack {
                Icon(name: iconName, size: 16, color: BeamColor.Generic.text.swiftUI)
                Text(prefixText)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .font(BeamFont.medium(size: 13).swiftUI)
                    +
                Text(group.noteInfo.title)
                    .foregroundColor(BeamColor.Beam.swiftUI)
                    .font(BeamFont.regular(size: 13).swiftUI)
            }
            .lineLimit(1)
            .padding(BeamSpacing._100)
            .onTapGesture {
                state.navigateToNote(id: group.noteInfo.id)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .zIndex(20)
        .animation(.easeInOut(duration: 0.3))
        .scaleEffect(isVisible ? 1.0 : 0.98)
        .offset(x: 0, y: isVisible ? 0.0 : -4.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3))
        .onAppear {
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                isVisible = false
            }
        }
    }
}

struct ShootCardConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        let target = PointAndShoot.Target(
            id: "uuid-uuid",
            rect: NSRect(x: 10, y: 10, width: 100, height: 100),
            mouseLocation: NSPoint(x: 20, y: 20),
            html: "",
            animated: false
        )
        let group = PointAndShoot.ShootGroup("uuid-uuid", [target], "https://example.com")
        PointAndShootCardConfirmationBox(group: group)
            .frame(width: 300, height: 70)
            .accessibility(identifier: "ShootCardConfirmationView")
    }
}

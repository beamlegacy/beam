import Foundation

extension AppDelegate {
    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: path) else {

            print("Could not parse \(String(describing: event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue)) \(reply)")
            return
        }

        // Process the URL.
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Invalid URL or path missing")
            return
        }

        parseBeamURL(components: components)
    }

    @discardableResult
    func parseBeamURL(components: NSURLComponents) -> Bool {
        // Process the URL.
        guard let urlPath = components.path else {
            print("Invalid URL or path missing")
            return false
        }

        guard components.host == Configuration.publicHostname else { return false }

        switch urlPath.dropFirst() {
        case "note":
            if let params = components.queryItems {
                if let noteId = params.first(where: { $0.name == "id" })?.value {
                    showNoteID(id: noteId)
                    return true
                } else if let noteTitle = params.first(where: { $0.name == "title" })?.value {
                    showNoteTitle(title: noteTitle)
                    return true
                }
            }
        case "bullet":
            if let params = components.queryItems,
               let bulletId = params.first(where: { $0.name == "id" })?.value {
                showBullet(id: bulletId)
                return true
            }
        default: break
        }

        print("Didn't detect link \(components)")

        return false
    }
}

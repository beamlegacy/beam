//
//  AdvancedPreferencesNetwork.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI
import BeamCore

struct AdvancedPreferencesNetwork: View {
    @State private var loading: Bool = false

    @State private var apiHostname: String = Configuration.apiHostname
    @State private var beamObjectsApiHostname: String = Configuration.beamObjectsApiHostname
    @State private var restApiHostname: String = Configuration.restApiHostname
    @State private var publicAPIpublishServer: String = Configuration.publicAPIpublishServer
    @State private var publicAPIembed: String = Configuration.publicAPIembed

    @State private var networkEnabled: Bool = Configuration.networkEnabled
    @State private var isDirectUploadOn = Configuration.beamObjectDataUploadOnSeparateCall
    @State private var isDirectUploadNIOOn = Configuration.directUploadNIO
    @State private var isDirectUploadAllObjectsOn = Configuration.directUploadAllObjects
    @State private var isDirectDownloadOn = Configuration.beamObjectDataOnSeparateCall
    @State private var isWebsocketEnabled = Configuration.websocketEnabled
    @State private var restBeamObject = Configuration.beamObjectOnRest

    private var apiHostnameBinding: Binding<String> { Binding<String>(get: {
        self.apiHostname
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiHostname = cleanValue
        Configuration.apiHostname = cleanValue
    })}

    private var beamObjectsApiHostnameBinding: Binding<String> { Binding<String>(get: {
        self.beamObjectsApiHostname
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.beamObjectsApiHostname = cleanValue
        Configuration.beamObjectsApiHostname = cleanValue
    })}

    private var restApiHostnameBinding: Binding<String> { Binding<String>(get: {
        self.restApiHostname
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.restApiHostname = cleanValue
        Configuration.restApiHostname = cleanValue
    })}

    private var publicAPIpublishServerBinding: Binding<String> { Binding<String>(get: {
        self.publicAPIpublishServer
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publicAPIpublishServer = cleanValue
        Configuration.publicAPIpublishServer = cleanValue
    })}

    private var publicAPIembedBinding: Binding<String> { Binding<String>(get: {
        self.publicAPIembed
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publicAPIembed = cleanValue
        Configuration.publicAPIembed = cleanValue
    })}

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            endpointsRows
            Settings.Row(hasDivider: true) {
                Text("Actions").labelsHidden()
            } content: {
                ResetAPIEndpointsButton
                SetAPIEndPointsToStagingButton
                SetAPIEndPointsToLocal
            }
            networkEnabledRow
            websocketEnabledRow
            directUploadRow
            directUploadNIORow
            directUploadAllObjectsRow
            directDownloadRow
            restBeamObjectRow
            Settings.Row {
                Text("").labelsHidden()
            } content: {
                Button(action: {
                    self.loading = true
                    Persistence.Sync.BeamObjects.last_received_at = nil
                    Persistence.Sync.BeamObjects.last_updated_at = nil
                    Task { @MainActor in
                         do {
                             try BeamObjectChecksum.deleteAll();
                             _ = try await AppDelegate.main.syncDataWithBeamObject(force: true)
                         } catch {
                             Logger.shared.logError("Error while syncing data: \(error)", category: .document)
                         }
                         self.loading = false
                     }
                }, label: {
                    Text("Force full sync").frame(minWidth: 100)
                })
                .disabled(loading)

                Button(action: {
                    do {
                        try BeamData.shared.currentAccount?.documentSynchroniser?.forceReceiveAll()
                    } catch {
                        Logger.shared.logError("Error while force recieve all document: \(error)", category: .document)
                    }
                }, label: {
                    Text("Force Receive All Document").frame(minWidth: 100)
                })
                .disabled(loading)
            }
        }
    }

    // MARK: - Rows
    @ViewBuilder
    var endpointsRows: some View {
        Group {
            Settings.Row {
                Text("GraphQL endpoint hostname")
            } content: {
                TextField("API hostname", text: apiHostnameBinding)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
            }
            Settings.Row {
                Text("BeamObjects GraphQL hostname")
            } content: {
                TextField("BeamObjects API hostname", text: beamObjectsApiHostnameBinding)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
            }
            Settings.Row {
                Text("REST endpoint hostname")
            } content: {
                TextField("REST API hostname", text: restApiHostnameBinding)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
            }
            Settings.Row {
                Text("Public API publish server")
            } content: {
                TextField("public api publish server", text: publicAPIpublishServerBinding)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
            }
            Settings.Row(hasDivider: true) {
                Text("Public API embed server")
            } content: {
                TextField("public api embed server", text: publicAPIembedBinding)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
            }
        }
    }

    private var networkEnabledRow: Settings.Row {
        Settings.Row {
            Text("Network")
        } content: {
            NetworkEnabled(networkEnabled: $networkEnabled)
        }
    }

    private var websocketEnabledRow: Settings.Row {
        Settings.Row {
            Text("Websocket")
        } content: {
            WebsocketEnabled(isWebsocketEnabled: $isWebsocketEnabled)
        }
    }
    private var directUploadRow: Settings.Row {
        Settings.Row {
            Text("Direct Upload")
        } content: {
            DirectUpload(isDirectUploadOn: $isDirectUploadOn)
        }
    }

    private var directUploadNIORow: Settings.Row {
        Settings.Row {
            Text("Direct Upload use NIO")
        } content: {
            DirectUploadNIO(isDirectUploadNIOOn: $isDirectUploadNIOOn)
        }
    }

    private var directUploadAllObjectsRow: Settings.Row {
        Settings.Row {
            Text("Direct Upload All Objects")
        } content: {
            DirectUploadAllObjects(isDirectUploadAllObjectsOn: $isDirectUploadAllObjectsOn)
        }
    }

    private var directDownloadRow: Settings.Row {
        Settings.Row {
            Text("Direct Download")
        } content: {
            DirectDownload(isDirectDownloadOn: $isDirectDownloadOn)
        }
    }

    private var restBeamObjectRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("REST API")
        } content: {
            RestBeamObject(restBeamObject: $restBeamObject)
        }
    }

    private var ResetAPIEndpointsButton: some View {
        Button(action: {
            Configuration.reset()
            apiHostname = Configuration.apiHostname
            restApiHostname = Configuration.restApiHostname
            publicAPIpublishServer = Configuration.publicAPIpublishServer
            publicAPIembed = Configuration.publicAPIembed
            promptEraseAllDataAlert()
        }, label: {
            // TODO: loc
            Text("Reset API Endpoints").frame(minWidth: 100)
        })
    }

    private var SetAPIEndPointsToStagingButton: some View {
        Button(action: {
            Configuration.setAPIEndPointsToStaging()
            apiHostname = Configuration.apiHostname
            restApiHostname = Configuration.restApiHostname
            publicAPIpublishServer = Configuration.publicAPIpublishServer
            publicAPIembed = Configuration.publicAPIembed
            promptEraseAllDataAlert()
        }, label: {
            // TODO: loc
            Text("Set API Endpoints to staging server").frame(minWidth: 100)
        })
    }

    private var SetAPIEndPointsToLocal: some View {
        Button(action: {
            Configuration.setAPIEndPointsToDevelopment()
            apiHostname = Configuration.apiHostname
            restApiHostname = Configuration.restApiHostname
            promptEraseAllDataAlert()
        }, label: {
            // TODO: loc
            Text("Set API Endpoints to local server").frame(minWidth: 100)
        })
    }
    private func promptEraseAllDataAlert() {
        let alert = NSAlert()
        alert.messageText = "Do you want to erase all local data?"
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 252, height: 16))
        alert.accessoryView = customView
        alert.addButton(withTitle: "Erase all data")
        alert.addButton(withTitle: "Close")
        alert.alertStyle = .warning
        guard let window = AppDelegate.main.settingsWindowController.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            for window in AppDelegate.main.windows {
                window.state.closeAllTabs(closePinnedTabs: true)
            }
            AppDelegate.main.deleteAllLocalData()
        }
    }
}

struct AdvancedPreferencesNetwork_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesNetwork()
    }
}

struct NetworkEnabled: View {
    @Binding var networkEnabled: Bool

    var body: some View {
        Toggle(isOn: $networkEnabled) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: networkEnabled, perform: {
                Configuration.networkEnabled = $0
            })
    }
}

struct WebsocketEnabled: View {
    @Binding var isWebsocketEnabled: Bool

    var body: some View {
        Toggle(isOn: $isWebsocketEnabled) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isWebsocketEnabled, perform: {
                Configuration.websocketEnabled = $0
            })
    }
}

struct DirectUpload: View {
    @Binding var isDirectUploadOn: Bool

    var body: some View {
        Toggle(isOn: $isDirectUploadOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDirectUploadOn) {
                Configuration.beamObjectDataUploadOnSeparateCall = $0
            }
    }
}

struct DirectUploadNIO: View {
    @Binding var isDirectUploadNIOOn: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $isDirectUploadNIOOn) {
                Text("Enabled")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: isDirectUploadNIOOn) {
                    Configuration.directUploadNIO = $0
                }
            Settings.SubtitleLabel("(Requires resync from scratch)")
        }
    }
}

struct DirectUploadAllObjects: View {
    @Binding var isDirectUploadAllObjectsOn: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $isDirectUploadAllObjectsOn) {
                Text("Enabled")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: isDirectUploadAllObjectsOn, perform: {
                    Configuration.directUploadAllObjects = $0
                })
            Settings.SubtitleLabel("(Requires resync from scratch)")
        }
    }
}

struct DirectDownload: View {
    @Binding var isDirectDownloadOn: Bool

    var body: some View {
        return Toggle(isOn: $isDirectDownloadOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDirectDownloadOn) {
                Configuration.beamObjectDataOnSeparateCall = $0
            }
    }
}

struct RestBeamObject: View {
    @Binding var restBeamObject: Bool

    var body: some View {
        return Toggle(isOn: $restBeamObject) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: restBeamObject) {
                Configuration.beamObjectOnRest = $0
            }
    }
}

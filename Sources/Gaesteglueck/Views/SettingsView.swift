#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @State private var connectionStatus: String? = nil
    @State private var isTestingConnection = false
    @State private var showingEventSetup = false

    var body: some View {
        Form {
            Section("Event") {
                Button("Event einrichten / bearbeiten") {
                    showingEventSetup = true
                }
            }

            Section("LM Studio") {
                TextField("Endpoint (z.B. http://localhost:1234)", text: $lmStudioEndpoint)
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Text("Verbindung testen")
                        if isTestingConnection {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isTestingConnection)

                if let status = connectionStatus {
                    HStack(spacing: 6) {
                        Image(systemName: status.hasPrefix("Verbunden") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(status.hasPrefix("Verbunden") ? Color.green : Color.red)
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(status.hasPrefix("Verbunden") ? Color.green : Color.red)
                    }
                }
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $showingEventSetup) {
            EventSetupView()
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionStatus = nil
        let endpoint = lmStudioEndpoint
        Task {
            let client = LMStudioClient(endpoint: endpoint)
            do {
                let modelID = try await client.checkConnection()
                await MainActor.run {
                    connectionStatus = "Verbunden: \(modelID)"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "Fehler: \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
    }
}
#endif

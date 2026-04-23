import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @Binding var showingSettings: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Audio"), footer: Text("When enabled, the app takes audio focus and shows media controls on the lock screen. When disabled, background audio (e.g. music) continues uninterrupted.")) {
                    Toggle("Lock Screen Controls", isOn: $appState.lockScreenControls)
                        .onChange(of: appState.lockScreenControls) { _, newValue in
                            BackgroundAudioManager.shared.applyMixingPreference(newValue)
                        }
                }

                Section {
                    Button("Return to Library", role: .destructive) {
                        appState.closeBook()
                        showingSettings = false
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            })
        }
    }
}

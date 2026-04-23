import SwiftUI

struct ReadingOptionsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Theme")) {
                    Picker("Color", selection: $appState.fontColor) {
                        Text("Light").tag("#E0E0E0")
                        Text("Sepia").tag("#F4ECD8")
                        Text("Dark").tag("#999999")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Text Size")) {
                    Stepper(String(format: "Size: %.1fx", appState.fontSize), value: $appState.fontSize, in: 0.8...3.0, step: 0.1)
                }
                
                Section(header: Text("Layout")) {
                    HStack {
                        Text("Horizontal Margin")
                        Slider(value: $appState.margin, in: 0.0...0.2)
                    }
                    HStack {
                        Text("Vertical Margin")
                        Slider(value: $appState.topBottomMargin, in: 0.0...0.2)
                    }
                    Picker("Alignment", selection: $appState.textJustify) {
                        Text("Left").tag("left")
                        Text("Justify").tag("justify")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Reading Options")
            .navigationBarItems(trailing: Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            })
            .onChange(of: appState.fontSize) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.fontColor) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.margin) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.topBottomMargin) { EpubManager.shared.saveProgress() }
            .onChange(of: appState.textJustify) { EpubManager.shared.saveProgress() }
        }
    }
}

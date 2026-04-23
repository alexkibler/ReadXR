import SwiftUI

struct NavBarView: View {
    @Binding var showingChapters: Bool
    @Binding var showingReadingOptions: Bool
    @Binding var showingHighlights: Bool
    @Binding var showingSettings: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            navBarButton(icon: "list.bullet", label: "Chapters") { showingChapters = true }
            navBarDivider()
            navBarButton(icon: "textformat.size", label: "Reading") { showingReadingOptions = true }
            navBarDivider()
            navBarButton(icon: "highlighter", label: "Highlights") { showingHighlights = true }
            navBarDivider()
            navBarButton(icon: "gearshape", label: "Settings") { showingSettings = true }
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
    
    private func navBarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func navBarDivider() -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 28)
    }
}

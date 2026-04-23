import SwiftUI
import Observation

@Observable
@MainActor
final class TrackpadViewModel {
    private let appState = AppState.shared
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    var didLongPress = false
    
    func handleDragEnded(value: DragGesture.Value) {
        guard appState.isBookLoaded else { return }
        
        if didLongPress {
            didLongPress = false
            return
        }
        
        let h = value.translation.width
        let v = value.translation.height
        
        if appState.isHighlightMode {
            if abs(h) < 10 && abs(v) < 10 {
                feedback.impactOccurred()
                NotificationCenter.default.post(name: .trackpadHighlightSave, object: nil)
            } else if abs(v) > abs(h) {
                if v > 30 {
                    feedback.impactOccurred()
                    let vel = abs(value.predictedEndTranslation.height - value.translation.height)
                    NotificationCenter.default.post(name: .trackpadHighlightMoveForward, object: nil, userInfo: ["velocity": vel])
                } else if v < -30 {
                    feedback.impactOccurred()
                    let vel = abs(value.predictedEndTranslation.height - value.translation.height)
                    NotificationCenter.default.post(name: .trackpadHighlightMoveBackward, object: nil, userInfo: ["velocity": vel])
                }
            } else {
                if h > 30 {
                    heavyFeedback.impactOccurred()
                    NotificationCenter.default.post(name: .trackpadHighlightExpandDown, object: nil)
                } else if h < -30 {
                    heavyFeedback.impactOccurred()
                    NotificationCenter.default.post(name: .trackpadHighlightExpandUp, object: nil)
                }
            }
        } else {
            if abs(h) < 10 && abs(v) < 10 {
                feedback.impactOccurred()
                appState.pageForward()
                print("Trackpad: Tap (Page Forward)")
            } else if h < -50 {
                feedback.impactOccurred()
                appState.pageForward()
                print("Trackpad: Swipe Left (Page Forward)")
            } else if h > 50 {
                feedback.impactOccurred()
                appState.pageBackward()
                print("Trackpad: Swipe Right (Page Backward)")
            } else if v < -50 {
                heavyFeedback.impactOccurred()
                appState.toggleMenu()
                print("Trackpad: Swipe Up (Menu)")
            }
        }
    }
    
    func handleLongPressEnded() {
        guard appState.isBookLoaded else { return }
        didLongPress = true
        heavyFeedback.impactOccurred()
        if appState.isHighlightMode {
            appState.isHighlightMode = false
            NotificationCenter.default.post(name: .trackpadHighlightClear, object: nil)
        } else {
            appState.isHighlightMode = true
            NotificationCenter.default.post(name: .trackpadHighlightStart, object: nil)
        }
    }
}

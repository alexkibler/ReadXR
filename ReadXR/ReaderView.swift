//
//  ReaderView.swift
//  ReadXR
//

import SwiftUI
import UIKit
import WebKit

/// The view displayed on the external display (AR glasses).
struct ReaderView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
        ZStack {
            Color.black.ignoresSafeArea()

            if appState.isBookLoaded {
                ZStack(alignment: .bottomTrailing) {
                    WebView(
                        htmlContent: appState.currentChapterHTML,
                        baseURL: appState.baseURL,
                        fontSize: appState.fontSize,
                        fontColor: appState.fontColor,
                        margin: appState.margin,
                        topBottomMargin: appState.topBottomMargin,
                        justify: appState.textJustify,
                        isExternalDisplayConnected: appState.isExternalDisplayConnected
                    )
                        .id("WebView") // don't reconstruct WebView on html change!
                        .padding(.vertical, geo.size.height * 0.05)

                    Text("Ch \(appState.currentChapterIndex + 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.1))
                        .padding()
                }
                .background(Color.black)
                .ignoresSafeArea()          // Fill the full external display, not just safe area
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("ReadXR")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        } // GeometryReader
    }
}

// MARK: - Custom WKWebView subclass for native text selection menu

class ReaderWKWebView: WKWebView {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        let highlightCommand = UICommand(
            title: "Highlight",
            image: UIImage(systemName: "highlighter"),
            action: #selector(highlightNativeSelection)
        )
        let highlightMenu = UIMenu(title: "", options: .displayInline, children: [highlightCommand])
        builder.insertSibling(highlightMenu, afterMenu: .standardEdit)
    }

    @objc func highlightNativeSelection(_ sender: Any?) {
        NotificationCenter.default.post(name: Notification.Name("nativeHighlightRequested"), object: nil)
    }
}

// MARK: - WebView

struct WebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    let fontSize: Double
    let fontColor: String
    let margin: Double
    let topBottomMargin: Double
    let justify: String
    let isExternalDisplayConnected: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: WebView
        var webView: WKWebView?
        var lastLoadedHTML: String = ""
        var lastIsExternalDisplayConnected: Bool = true
        /// Tracks the intended scroll destination independently of the animated position,
        /// so rapid page turns always compute from the correct logical page rather than
        /// an in-flight (mid-animation) content offset.
        var targetOffset: CGFloat = 0

        init(_ parent: WebView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(pageForward), name: .trackpadPageForward, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(pageBackward), name: .trackpadPageBackward, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(startHighlight), name: .trackpadHighlightStart, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(clearHighlight), name: .trackpadHighlightClear, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(moveHighlightFwd), name: .trackpadHighlightMoveForward, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(moveHighlightBack), name: .trackpadHighlightMoveBackward, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(expandHighlightDown), name: .trackpadHighlightExpandDown, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(expandHighlightUp), name: .trackpadHighlightExpandUp, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(saveHighlight), name: .trackpadHighlightSave, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollToHighlight(_:)), name: .scrollToHighlight, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleScrollToPercentage(_:)), name: .scrollToPercentage, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(captureTopSentenceIdAndNavigate(_:)), name: .captureTopSentenceAndNavigate, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleNativeHighlightRequested), name: Notification.Name("nativeHighlightRequested"), object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func startHighlight() {
            webView?.evaluateJavaScript("startHighlightMode();") { _, _ in }
        }
        @objc func clearHighlight() {
            webView?.evaluateJavaScript("clearHighlightMode();") { _, _ in }
        }
        @objc func moveHighlightFwd(notification: Notification) {
            let velocity = notification.userInfo?["velocity"] as? CGFloat ?? 0
            let amount = velocity > 150 ? 5 : 1
            webView?.evaluateJavaScript("moveHighlight(\(amount));") { _, _ in }
        }
        @objc func moveHighlightBack(notification: Notification) {
            let velocity = notification.userInfo?["velocity"] as? CGFloat ?? 0
            let amount = velocity > 150 ? -5 : -1
            webView?.evaluateJavaScript("moveHighlight(\(amount));") { _, _ in }
        }
        @objc func expandHighlightDown() {
            webView?.evaluateJavaScript("resizeHighlight(1);") { _, _ in }
        }
        @objc func expandHighlightUp() {
            webView?.evaluateJavaScript("resizeHighlight(-1);") { _, _ in }
        }
        @objc func saveHighlight() {
            webView?.evaluateJavaScript("getHighlightData();") { [weak self] result, error in
                guard let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let parsed = try? JSONDecoder().decode(HighlightData.self, from: data),
                      !parsed.text.isEmpty else {
                    Task { @MainActor in
                        self?.clearHighlight()
                        AppState.shared.isHighlightMode = false
                    }
                    return
                }
                Task { @MainActor in
                    AppState.shared.saveCurrentHighlight(parsed.text, sentenceStartId: parsed.startId, sentenceEndId: parsed.endId)
                    // Apply persistent highlights on the live WebView without a page reload
                    let appState = AppState.shared
                    let locations = appState.activeBookHighlights
                        .filter { $0.chapterIndex == appState.currentChapterIndex }
                        .map { HighlightLocation(highlight: $0) }
                    if let encoded = try? JSONEncoder().encode(locations),
                       let jsStr = String(data: encoded, encoding: .utf8) {
                        self?.webView?.evaluateJavaScript("applyPersistentHighlights(\(jsStr));") { _, _ in }
                    }
                    self?.clearHighlight()
                    AppState.shared.isHighlightMode = false
                }
            }
        }

        @objc func handleNativeHighlightRequested() {
            webView?.evaluateJavaScript("saveNativeSelection();") { [weak self] result, _ in
                guard let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let parsed = try? JSONDecoder().decode(HighlightData.self, from: data),
                      !parsed.text.isEmpty else { return }
                Task { @MainActor in
                    AppState.shared.saveCurrentHighlight(parsed.text, sentenceStartId: parsed.startId, sentenceEndId: parsed.endId)
                    let appState = AppState.shared
                    let locations = appState.activeBookHighlights
                        .filter { $0.chapterIndex == appState.currentChapterIndex }
                        .map { HighlightLocation(highlight: $0) }
                    if let encoded = try? JSONEncoder().encode(locations),
                       let jsStr = String(data: encoded, encoding: .utf8) {
                        self?.webView?.evaluateJavaScript("applyPersistentHighlights(\(jsStr));") { _, _ in }
                    }
                    self?.webView?.evaluateJavaScript("window.getSelection().removeAllRanges();") { _, _ in }
                }
            }
        }

        @objc func handleScrollToHighlight(_ notification: Notification) {
            if let sid = notification.userInfo?["sentenceId"] as? Int {
                webView?.evaluateJavaScript("scrollToHighlightId(\(sid));") { _, _ in }
            }
        }

        @objc func handleScrollToPercentage(_ notification: Notification) {
            guard let scrollView = webView?.scrollView,
                  let pct = notification.userInfo?["percentage"] as? Double else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let width = scrollView.bounds.width
                let maxOffset = scrollView.contentSize.width - width
                guard maxOffset > 0 else { return }
                let target = maxOffset * pct
                let aligned = round(target / width) * width
                let final = min(max(aligned, 0), maxOffset)
                self.targetOffset = final
                scrollView.setContentOffset(CGPoint(x: final, y: 0), animated: false)
            }
        }

        @objc func captureTopSentenceIdAndNavigate(_ notification: Notification) {
            guard let highlight = notification.object as? Highlight else { return }
            webView?.evaluateJavaScript("getTopSentenceId();") { result, _ in
                Task { @MainActor in
                    let appState = AppState.shared

                    if appState.returnChapterIndex == nil {
                        appState.returnChapterIndex = appState.currentChapterIndex
                        appState.returnScrollPercentage = appState.currentScrollPercentage
                        if let sid = result as? Int {
                            appState.returnSentenceId = sid
                        }
                    }

                    guard let chIdx = highlight.chapterIndex else { return }
                    let isSameChapter = chIdx == appState.currentChapterIndex
                    appState.currentChapterIndex = chIdx

                    if let highlightSid = highlight.sentenceStartId {
                        if isSameChapter {
                            NotificationCenter.default.post(name: .scrollToHighlight, object: nil, userInfo: ["sentenceId": highlightSid])
                        } else {
                            appState.pendingHighlightSentenceId = highlightSid
                            EpubManager.shared.loadCurrentChapter()
                            EpubManager.shared.saveProgress()
                        }
                    } else if let scrollPct = highlight.scrollPercentage {
                        if isSameChapter {
                            NotificationCenter.default.post(name: .scrollToPercentage, object: nil, userInfo: ["percentage": scrollPct])
                        } else {
                            appState.currentScrollPercentage = scrollPct
                            EpubManager.shared.loadCurrentChapter()
                            EpubManager.shared.saveProgress()
                        }
                    }
                }
            }
        }

        // After the page fully loads the WebView is in its final window with correct dimensions.
        // Call the in-page applyLayout() which uses window.innerWidth/innerHeight — these are
        // accurate at this point regardless of what context the HTML was loaded in.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("applyLayout();") { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let scrollView = webView.scrollView
                    let width = scrollView.bounds.width
                    let maxOffset = scrollView.contentSize.width - width
                    if maxOffset > 0 {
                        let restored = maxOffset * AppState.shared.currentScrollPercentage
                        let alignedOffset = round(restored / width) * width
                        let finalOffset = min(max(alignedOffset, 0), maxOffset)
                        self.targetOffset = finalOffset
                        scrollView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: false)
                    } else {
                        self.targetOffset = 0
                    }
                    // Re-apply saved highlights for this chapter
                    let appState = AppState.shared
                    let chIdx = appState.currentChapterIndex
                    let locations = appState.activeBookHighlights
                        .filter { $0.chapterIndex == chIdx }
                        .map { HighlightLocation(highlight: $0) }
                    if !locations.isEmpty,
                       let data = try? JSONEncoder().encode(locations),
                       let jsonStr = String(data: data, encoding: .utf8) {
                        webView.evaluateJavaScript("applyPersistentHighlights(\(jsonStr));") { _, _ in }
                    }
                    // Scroll to a specific highlight if requested
                    if let sid = appState.pendingHighlightSentenceId {
                        appState.pendingHighlightSentenceId = nil
                        webView.evaluateJavaScript("scrollToHighlightId(\(sid));") { _, _ in }
                    }
                }
            }
        }

        // MARK: UIScrollViewDelegate — sync progress when user physically scrolls (iPhone mode)

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let width = scrollView.bounds.width
            let maxOffset = scrollView.contentSize.width - width
            guard maxOffset > 0 else { return }

            targetOffset = scrollView.contentOffset.x

            let pct = scrollView.contentOffset.x / maxOffset
            Task { @MainActor in
                AppState.shared.currentScrollPercentage = pct
                EpubManager.shared.saveProgress()
            }
        }

        @objc func pageForward() {
            guard let scrollView = webView?.scrollView else { return }
            let width = scrollView.bounds.width
            let contentWidth = max(scrollView.contentSize.width, width)
            if targetOffset + width >= contentWidth - 5 {
                Task { @MainActor in EpubManager.shared.nextChapter() }
            } else {
                targetOffset = min(targetOffset + width, contentWidth - width)
                let dest = CGPoint(x: targetOffset, y: 0)
                UIView.animate(withDuration: 0.3, delay: 0,
                               options: [.curveEaseOut, .beginFromCurrentState]) {
                    scrollView.contentOffset = dest
                }
                let pct = targetOffset / max(1.0, contentWidth - width)
                Task { @MainActor in
                    AppState.shared.currentScrollPercentage = pct
                    EpubManager.shared.saveProgress()
                }
            }
        }

        @objc func pageBackward() {
            guard let scrollView = webView?.scrollView else { return }
            let width = scrollView.bounds.width
            let contentWidth = max(scrollView.contentSize.width, width)
            if targetOffset <= 5 {
                Task { @MainActor in EpubManager.shared.previousChapter() }
            } else {
                targetOffset = max(targetOffset - width, 0)
                let dest = CGPoint(x: targetOffset, y: 0)
                UIView.animate(withDuration: 0.3, delay: 0,
                               options: [.curveEaseOut, .beginFromCurrentState]) {
                    scrollView.contentOffset = dest
                }
                let pct = targetOffset / max(1.0, contentWidth - width)
                Task { @MainActor in
                    AppState.shared.currentScrollPercentage = pct
                    EpubManager.shared.saveProgress()
                }
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = ReaderWKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = !isExternalDisplayConnected
        webView.scrollView.isPagingEnabled = !isExternalDisplayConnected
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.lastIsExternalDisplayConnected = isExternalDisplayConnected
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Toggle native scroll and user-select when display mode changes
        if context.coordinator.lastIsExternalDisplayConnected != isExternalDisplayConnected {
            context.coordinator.lastIsExternalDisplayConnected = isExternalDisplayConnected
            uiView.scrollView.isScrollEnabled = !isExternalDisplayConnected
            uiView.scrollView.isPagingEnabled = !isExternalDisplayConnected
            let selectValue = isExternalDisplayConnected ? "none" : "text"
            uiView.evaluateJavaScript("document.body.style.webkitUserSelect = '\(selectValue)'; document.body.style.userSelect = '\(selectValue)';") { _, _ in }
        }

        if context.coordinator.lastLoadedHTML != htmlContent {
            uiView.loadHTMLString(buildHTML(htmlContent), baseURL: baseURL)
            context.coordinator.lastLoadedHTML = htmlContent
        } else {
            // Snapshot current position BEFORE the reflow so we can restore it after.
            // Changing margin/font changes column count, which moves content at a fixed
            // absolute offset — saving and restoring the percentage keeps the user on the
            // same logical page through style adjustments.
            let sv = uiView.scrollView
            let preWidth = sv.bounds.width
            let preMax = sv.contentSize.width - preWidth
            let prePct = preMax > 1 ? (sv.contentOffset.x / preMax) : 0.0

            let js = "updateStyles(\(fontSize), '\(fontColor)', '\(justify)', \(margin), \(topBottomMargin));"
            uiView.evaluateJavaScript(js) { [weak uiView] _, _ in
                guard let uiView else { return }
                // Give the browser one frame to finish the reflow before restoring position.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let sv = uiView.scrollView
                    let w = sv.bounds.width
                    let maxOff = sv.contentSize.width - w
                    guard maxOff > 0, w > 0 else { return }
                    let target = maxOff * prePct
                    let aligned = round(target / w) * w
                    sv.setContentOffset(CGPoint(x: min(max(aligned, 0), maxOff), y: 0), animated: false)
                }
            }
        }
    }

    private func buildHTML(_ content: String) -> String {
        let userSelectValue = isExternalDisplayConnected ? "none" : "text"
        
        let cssPath = Bundle.main.path(forResource: "ReaderStyles", ofType: "css")
        let jsPath = Bundle.main.path(forResource: "ReaderScripts", ofType: "js")
        
        let css = (try? String(contentsOfFile: cssPath ?? "")) ?? ""
        let js = (try? String(contentsOfFile: jsPath ?? "")) ?? ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            :root {
                --user-font-size: \(fontSize)em;
                --user-font-color: \(fontColor);
                --user-justify: \(justify);
                --raw-margin: \(margin);
                --user-tb-margin: \(Int(topBottomMargin * 100))vh;
                --user-margin-px: 0px;
                --user-gap-px: 0px;
            }
            \(css)
            body {
                -webkit-user-select: \(userSelectValue);
                user-select: \(userSelectValue);
            }
            </style>
            <script>
            \(js)
            </script>
        </head>
        <body>\(content)</body>
        </html>
        """
    }
}

// MARK: - Highlight helpers (used by WebView.Coordinator)

private struct HighlightData: Decodable {
    let text: String
    let startId: Int
    let endId: Int
}

private struct HighlightLocation: Encodable {
    let startId: Int   // -1 when unknown (old highlight)
    let endId: Int     // -1 when unknown (old highlight)
    let text: String?  // used as fallback when startId == -1

    init(highlight: Highlight) {
        self.startId = highlight.sentenceStartId ?? -1
        self.endId = highlight.sentenceEndId ?? -1
        self.text = (highlight.sentenceStartId == nil) ? highlight.text : nil
    }
}

#Preview {
    ReaderView()
        .environment(AppState.shared)
}

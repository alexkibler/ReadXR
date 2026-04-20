//
//  ReaderView.swift
//  ReadXR
//

import SwiftUI
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
                        justify: appState.textJustify
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
                    Text("Waiting for book import on iPhone...")
                        .foregroundColor(.gray)
                }
            }
        }
        } // GeometryReader
    }
}

struct WebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    let fontSize: Double
    let fontColor: String
    let margin: Double
    let topBottomMargin: Double
    let justify: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var webView: WKWebView?
        var lastLoadedHTML: String = ""

        init(_ parent: WebView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(pageForward), name: .trackpadPageForward, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(pageBackward), name: .trackpadPageBackward, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
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
                        let targetOffset = maxOffset * AppState.shared.currentScrollPercentage
                        let alignedOffset = round(targetOffset / width) * width
                        let finalOffset = min(max(alignedOffset, 0), maxOffset)
                        scrollView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: false)
                    }
                }
            }
        }

        @objc func pageForward() {
            guard let scrollView = webView?.scrollView else { return }
            let offset = scrollView.contentOffset.x
            let width = scrollView.bounds.width
            let contentWidth = max(scrollView.contentSize.width, width)
            if offset + width >= contentWidth - 5 {
                Task { @MainActor in EpubManager.shared.nextChapter() }
            } else {
                let targetX = min(offset + width, contentWidth - width)
                scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: true)
                Task { @MainActor in
                    AppState.shared.currentScrollPercentage = targetX / max(1.0, contentWidth - width)
                    EpubManager.shared.saveProgress()
                }
            }
        }

        @objc func pageBackward() {
            guard let scrollView = webView?.scrollView else { return }
            let offset = scrollView.contentOffset.x
            let width = scrollView.bounds.width
            let contentWidth = max(scrollView.contentSize.width, width)
            if offset <= 5 {
                Task { @MainActor in EpubManager.shared.previousChapter() }
            } else {
                let targetX = max(offset - width, 0)
                scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: true)
                Task { @MainActor in
                    AppState.shared.currentScrollPercentage = targetX / max(1.0, contentWidth - width)
                    EpubManager.shared.saveProgress()
                }
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedHTML != htmlContent {
            uiView.loadHTMLString(buildHTML(htmlContent), baseURL: baseURL)
            context.coordinator.lastLoadedHTML = htmlContent
        } else {
            let js = "updateStyles(\(fontSize), '\(fontColor)', '\(justify)', \(margin), \(topBottomMargin));"
            uiView.evaluateJavaScript(js)
        }
    }

    private func buildHTML(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            :root {
                --user-font-size: \(fontSize)em;
                --user-font-color: \(fontColor);
                --user-margin: \(Int(margin * 100))vw;
                --user-tb-margin: \(Int(topBottomMargin * 100))vh;
                --user-gap: \(Int(margin * 200))vw;
                --user-justify: \(justify);
            }
            html {
                height: 100%;
            }
            body {
                margin: 0;
                padding: 0;
                padding-top: var(--user-tb-margin) !important;
                padding-bottom: var(--user-tb-margin) !important;
                padding-left: var(--user-margin) !important;
                padding-right: var(--user-margin) !important;
                height: 100%;
                /* overflow-y hidden stops vertical scroll; horizontal overflow is intentional —
                   CSS columns extend the document width so the scrollView can page through them. */
                overflow-y: hidden;
                background-color: transparent !important;
                color: var(--user-font-color) !important;
                font-family: -apple-system, sans-serif;
                font-size: var(--user-font-size) !important;
                text-align: var(--user-justify) !important;
                line-height: 1.8;
                overflow-wrap: break-word;
                word-wrap: break-word;
                box-sizing: border-box;
                column-gap: var(--user-gap) !important;
            }
            img, video, svg {
                max-width: 100% !important;
                height: auto !important;
                display: block !important;
                margin: 0 auto !important;
            }
            a { color: #6EA8FF; }
            </style>
            <script>
            // applyLayout() is called on DOMContentLoaded, on viewport resize (fires when the
            // WKWebView is moved from the iPhone window to the external display window), and
            // again from Swift's webView(_:didFinish:) as a final guarantee.
            function applyLayout() {
                var w = window.innerWidth;
                var h = window.innerHeight;
                if (w > 0 && h > 0) {
                    document.body.style.columnWidth = w + 'px';
                    document.body.style.height = h + 'px';
                }
            }
            function updateStyles(size, color, justify, margin, tbMargin) {
                var root = document.documentElement;
                root.style.setProperty('--user-font-size', size + 'em');
                root.style.setProperty('--user-font-color', color);
                root.style.setProperty('--user-justify', justify);
                root.style.setProperty('--user-margin', Math.floor(margin * 100) + 'vw');
                root.style.setProperty('--user-tb-margin', Math.floor(tbMargin * 100) + 'vh');
                root.style.setProperty('--user-gap', Math.floor(margin * 200) + 'vw');
                applyLayout();
            }
            document.addEventListener('DOMContentLoaded', applyLayout);
            window.addEventListener('resize', applyLayout);
            </script>
        </head>
        <body>\(content)</body>
        </html>
        """
    }
}

#Preview {
    ReaderView()
        .environment(AppState.shared)
}

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
                    WebView(htmlContent: appState.currentChapterHTML, baseURL: appState.baseURL)
                        .id(appState.currentChapterHTML.hashValue)
                        .padding(.horizontal, geo.size.width * 0.05)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var webView: WKWebView?

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
            webView.evaluateJavaScript("applyLayout();", completionHandler: nil)
        }

        @objc func pageForward() {
            guard let scrollView = webView?.scrollView else { return }
            let offset = scrollView.contentOffset.x
            let width = scrollView.bounds.width
            let contentWidth = max(scrollView.contentSize.width, width)
            if offset + width >= contentWidth - 5 {
                Task { @MainActor in EpubManager.shared.nextChapter() }
            } else {
                scrollView.setContentOffset(CGPoint(x: min(offset + width, contentWidth - width), y: 0), animated: true)
            }
        }

        @objc func pageBackward() {
            guard let scrollView = webView?.scrollView else { return }
            let offset = scrollView.contentOffset.x
            let width = scrollView.bounds.width
            if offset <= 5 {
                Task { @MainActor in EpubManager.shared.previousChapter() }
            } else {
                scrollView.setContentOffset(CGPoint(x: max(offset - width, 0), y: 0), animated: true)
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
        uiView.loadHTMLString(buildHTML(htmlContent), baseURL: baseURL)
    }

    private func buildHTML(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            html {
                height: 100%;
            }
            body {
                margin: 0;
                padding: 0;
                height: 100%;
                /* overflow-y hidden stops vertical scroll; horizontal overflow is intentional —
                   CSS columns extend the document width so the scrollView can page through them. */
                overflow-y: hidden;
                background-color: transparent !important;
                color: #E0E0E0 !important;
                font-family: -apple-system, sans-serif;
                font-size: 1.3em;
                line-height: 1.8;
                overflow-wrap: break-word;
                word-wrap: break-word;
                box-sizing: border-box;
                column-gap: 0;
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

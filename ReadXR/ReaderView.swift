//
//  ReaderView.swift
//  ReadXR
//
//  Created by Gemini CLI on 4/19/26.
//

import SwiftUI
import WebKit

/// The view displayed on the external display (AR glasses).
/// Uses a WKWebView to render ePub HTML chapters with forced OLED-black styling.
struct ReaderView: View {
    @Environment(AppState.self) private var appState
    
    // Adjustable padding to avoid lens distortion in AR glasses
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Force the underlying SwiftUI container to pure black
            Color.black.edgesIgnoringSafeArea(.all)
            
            if appState.isBookLoaded {
                ZStack(alignment: .bottomTrailing) {
                    WebView(htmlContent: appState.currentChapterHTML, baseURL: appState.baseURL)
                        .id(appState.currentChapterHTML.hashValue)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                    
                    Text("Ch \(appState.currentChapterIndex + 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.1))
                        .padding()
                }
                .background(Color.black)
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
    }
}

/// A WKWebView wrapper that handles HTML rendering and CSS injection.
struct WebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
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
        
        @objc func pageForward() {
            guard let scrollView = webView?.scrollView else { return }
            
            let offset = scrollView.contentOffset.x
            let width = scrollView.bounds.width
            // Use maximum of contentSize.width and bounds.width in case content is smaller than screen
            let contentWidth = max(scrollView.contentSize.width, width)
            
            if offset + width >= contentWidth - 5 {
                Task { @MainActor in
                    EpubManager.shared.nextChapter()
                }
            } else {
                let newOffset = min(offset + width, contentWidth - width)
                scrollView.setContentOffset(CGPoint(x: newOffset, y: 0), animated: true)
            }
        }
        
        @objc func pageBackward() {
            guard let scrollView = webView?.scrollView else { return }
            
            let offset = scrollView.contentOffset.x
            let width = scrollView.bounds.width
            
            if offset <= 5 {
                Task { @MainActor in
                    EpubManager.shared.previousChapter()
                }
            } else {
                let newOffset = max(offset - width, 0)
                scrollView.setContentOffset(CGPoint(x: newOffset, y: 0), animated: true)
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        
        // Disable scrolling if navigation is handled via trackpad
        webView.scrollView.isScrollEnabled = false 
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Prepare the CSS to paginate horizontally and force OLED-friendly colors
        let css = """
        html {
            height: 100%;
            width: 100%;
        }
        body {
            height: 100%;
            width: 100%;
            margin: 0;
            padding: 0;
            column-width: 100vw;
            column-gap: 0;
            background-color: transparent !important;
            color: #E0E0E0 !important;
            font-family: -apple-system, sans-serif;
            font-size: 1.3em;
            line-height: 1.8;
            overflow-wrap: break-word;
            word-wrap: break-word;
            box-sizing: border-box;
        }
        img, video, iframe {
            max-width: 100vw !important;
            max-height: 100vh !important;
            display: block;
            margin: 0 auto;
            object-fit: contain;
        }
        """
        
        // Wrap the content in a basic HTML structure
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, shrink-to-fit=no">
            <style>\(css)</style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        uiView.loadHTMLString(styledHTML, baseURL: baseURL)
    }
}

#Preview {
    ReaderView()
        .environment(AppState.shared)
}

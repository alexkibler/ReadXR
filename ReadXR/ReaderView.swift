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
    var horizontalPadding: CGFloat = 40
    var verticalPadding: CGFloat = 60
    
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
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        
        // Disable scrolling if navigation is handled via trackpad
        webView.scrollView.isScrollEnabled = false 
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Prepare the CSS to force OLED-friendly colors
        let css = """
        body {
            background-color: transparent !important;
            color: #E0E0E0 !important;
            font-family: -apple-system, sans-serif;
            font-size: 1.3em;
            line-height: 1.8;
            padding: 20px;
        }
        """
        
        // Wrap the content in a basic HTML structure
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
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

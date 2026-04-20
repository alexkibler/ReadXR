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
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func startHighlight() {
            webView?.evaluateJavaScript("startHighlightMode();")
        }
        @objc func clearHighlight() {
            webView?.evaluateJavaScript("clearHighlightMode();")
        }
        @objc func moveHighlightFwd(notification: Notification) {
            let velocity = notification.userInfo?["velocity"] as? CGFloat ?? 0
            let amount = velocity > 150 ? 5 : 1
            webView?.evaluateJavaScript("moveHighlight(\(amount));")
        }
        @objc func moveHighlightBack(notification: Notification) {
            let velocity = notification.userInfo?["velocity"] as? CGFloat ?? 0
            let amount = velocity > 150 ? -5 : -1
            webView?.evaluateJavaScript("moveHighlight(\(amount));")
        }
        @objc func expandHighlightDown() {
            webView?.evaluateJavaScript("resizeHighlight(1);")
        }
        @objc func expandHighlightUp() {
            webView?.evaluateJavaScript("resizeHighlight(-1);")
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
                        self?.webView?.evaluateJavaScript("applyPersistentHighlights(\(jsStr));")
                    }
                    self?.clearHighlight()
                    AppState.shared.isHighlightMode = false
                }
            }
        }

        @objc func handleScrollToHighlight(_ notification: Notification) {
            if let sid = notification.userInfo?["sentenceId"] as? Int {
                webView?.evaluateJavaScript("scrollToHighlightId(\(sid));")
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
                scrollView.setContentOffset(CGPoint(x: final, y: 0), animated: true)
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
                        let targetOffset = maxOffset * AppState.shared.currentScrollPercentage
                        let alignedOffset = round(targetOffset / width) * width
                        let finalOffset = min(max(alignedOffset, 0), maxOffset)
                        scrollView.setContentOffset(CGPoint(x: finalOffset, y: 0), animated: false)
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
                        webView.evaluateJavaScript("applyPersistentHighlights(\(jsonStr));")
                    }
                    // Scroll to a specific highlight if requested
                    if let sid = appState.pendingHighlightSentenceId {
                        appState.pendingHighlightSentenceId = nil
                        webView.evaluateJavaScript("scrollToHighlightId(\(sid));")
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
            .readxr-highlight {
                background-color: rgba(255, 235, 59, 0.4);
                border-radius: 3px;
                color: black !important;
            }
            .readxr-saved-highlight {
                background-color: rgba(255, 210, 0, 0.22);
                border-radius: 2px;
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
            var sentencesWrapped = false;
            var highlightStartIndex = 0;
            var highlightEndIndex = 0;

            function wrapSentences() {
                if(sentencesWrapped) return;
                var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
                var nodes = [];
                while(walker.nextNode()) {
                    var pName = walker.currentNode.parentNode.nodeName;
                    if(pName !== 'SCRIPT' && pName !== 'STYLE' && walker.currentNode.textContent.trim().length > 0) {
                        nodes.push(walker.currentNode);
                    }
                }
                var sentenceId = 0;
                nodes.forEach(function(node) {
                    var text = node.textContent;
                    var match;
                    var regex = /([^.!?]+[.!?]+(?:\\s+|$)|[^.!?]+$)/g;
                    var p = node.parentNode;
                    var frag = document.createDocumentFragment();
                    var matchedAny = false;
                    while ((match = regex.exec(text)) !== null) {
                        matchedAny = true;
                        var str = match[0];
                        if (str.trim().length === 0) {
                            frag.appendChild(document.createTextNode(str));
                            continue;
                        }
                        var span = document.createElement('span');
                        span.className = 'readxr-sentence';
                        span.dataset.sid = sentenceId++;
                        span.textContent = str;
                        frag.appendChild(span);
                    }
                    if (matchedAny) {
                        p.replaceChild(frag, node);
                    }
                });
                sentencesWrapped = true;
            }

            function startHighlightMode() {
                wrapSentences();
                var spans = document.querySelectorAll('.readxr-sentence');
                var w = window.innerWidth;
                for(var i=0; i<spans.length; i++) {
                    var rect = spans[i].getBoundingClientRect();
                    if (rect.left >= 0 && rect.left < w) {
                        highlightStartIndex = i;
                        highlightEndIndex = i;
                        updateHighlightUI();
                        return;
                    }
                }
            }

            function updateHighlightUI() {
                var els = document.querySelectorAll('.readxr-sentence.readxr-highlight');
                for(var i=0; i<els.length; i++) els[i].classList.remove('readxr-highlight');
                var start = Math.min(highlightStartIndex, highlightEndIndex);
                var end = Math.max(highlightStartIndex, highlightEndIndex);
                var spans = document.querySelectorAll('.readxr-sentence');
                for(var i=start; i<=end; i++) {
                    if(spans[i]) spans[i].classList.add('readxr-highlight');
                }
                ensureVisible(highlightStartIndex);
                ensureVisible(highlightEndIndex);
            }

            function moveHighlight(amount) {
                highlightStartIndex += amount;
                highlightEndIndex += amount;
                var spans = document.querySelectorAll('.readxr-sentence');
                if (highlightStartIndex < 0) { highlightStartIndex = 0; highlightEndIndex = 0; }
                if (highlightEndIndex >= spans.length) { 
                    highlightStartIndex = spans.length - 1; 
                    highlightEndIndex = spans.length - 1; 
                }
                updateHighlightUI();
            }

            function resizeHighlight(amount) {
                if (amount > 0) {
                    highlightEndIndex += amount;
                } else {
                    if (highlightEndIndex > highlightStartIndex) {
                        highlightEndIndex += amount;
                    } else if (highlightEndIndex < highlightStartIndex) {
                        highlightEndIndex += Math.abs(amount);
                    }
                }
                var spans = document.querySelectorAll('.readxr-sentence');
                if (highlightEndIndex >= spans.length) highlightEndIndex = spans.length - 1;
                updateHighlightUI();
            }

            function ensureVisible(index) {
                var span = document.querySelectorAll('.readxr-sentence')[index];
                if(span) {
                    var rect = span.getBoundingClientRect();
                    var w = window.innerWidth;
                    if (rect.left < 0 || rect.left >= w) {
                        var colWidth = w;
                        var pagesToMove = Math.floor(rect.left / colWidth);
                        window.scrollBy({left: pagesToMove * colWidth, behavior: 'instant'});
                    }
                }
            }

            function getHighlightData() {
                var start = Math.min(highlightStartIndex, highlightEndIndex);
                var end = Math.max(highlightStartIndex, highlightEndIndex);
                var spans = document.querySelectorAll('.readxr-sentence');
                var text = "";
                for(var i=start; i<=end; i++) {
                    if(spans[i]) text += spans[i].textContent + " ";
                }
                var startId = spans[start] ? parseInt(spans[start].dataset.sid) : -1;
                var endId = spans[end] ? parseInt(spans[end].dataset.sid) : -1;
                return JSON.stringify({text: text.trim(), startId: startId, endId: endId});
            }

            function getTopSentenceId() {
                wrapSentences();
                var spans = document.querySelectorAll('.readxr-sentence');
                var w = window.innerWidth;
                for(var i=0; i<spans.length; i++) {
                    var rect = spans[i].getBoundingClientRect();
                    // In a multi-column layout handled via UIScrollView,
                    // the elements on the currently visible page will have rect.left >= 0 and rect.left < viewport width.
                    if (rect.left >= 0 && rect.left < w && rect.width > 0) {
                        return parseInt(spans[i].dataset.sid);
                    }
                }
                return null;
            }

            function clearHighlightMode() {
                var els = document.querySelectorAll('.readxr-sentence.readxr-highlight');
                for(var i=0; i<els.length; i++) els[i].classList.remove('readxr-highlight');
            }

            function applyPersistentHighlights(locations) {
                wrapSentences();
                var spans = Array.from(document.querySelectorAll('.readxr-sentence'));
                spans.forEach(function(s) { s.classList.remove('readxr-saved-highlight'); });
                locations.forEach(function(loc) {
                    if (loc.startId >= 0) {
                        // ID-based match (new highlights)
                        spans.forEach(function(span) {
                            var sid = parseInt(span.dataset.sid);
                            if (sid >= loc.startId && sid <= loc.endId) {
                                span.classList.add('readxr-saved-highlight');
                            }
                        });
                    } else if (loc.text) {
                        // Text-based fallback (old highlights)
                        var target = loc.text.trim();
                        for (var i = 0; i < spans.length; i++) {
                            for (var j = i; j < spans.length && j < i + 30; j++) {
                                var combined = spans.slice(i, j+1).map(function(s) { return s.textContent; }).join(' ').trim();
                                if (combined === target) {
                                    for (var k = i; k <= j; k++) { spans[k].classList.add('readxr-saved-highlight'); }
                                    i = j;
                                    break;
                                }
                                if (combined.length > target.length + 30) break;
                            }
                        }
                    }
                });
            }

            function scrollToHighlightId(startSid) {
                wrapSentences();
                ensureVisible(startSid);
            }

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

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
        var regex = /([^.!?]+[.!?]+(?:\s+|$)|[^.!?]+$)/g;
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

function saveNativeSelection() {
    var sel = window.getSelection();
    if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return null;

    var text = sel.toString();
    var range = sel.getRangeAt(0);

    wrapSentences(); // Ensure DOM has sids

    function findSid(node) {
        while (node && node !== document.body) {
            if (node.nodeType === 1 && node.hasAttribute('data-sid')) {
                return parseInt(node.getAttribute('data-sid'));
            }
            node = node.parentNode;
        }
        return -1;
    }

    var startId = findSid(range.startContainer);
    var endId = findSid(range.endContainer);

    // Swap if selection was dragged backwards
    if (startId !== -1 && endId !== -1 && startId > endId) {
        var temp = startId; startId = endId; endId = temp;
    }

    // Build text from the full expanded sentence spans so the stored text
    // matches what actually gets highlighted (not just the raw finger selection).
    if (startId !== -1 && endId !== -1) {
        var allSpans = document.querySelectorAll('.readxr-sentence');
        var expandedText = "";
        for (var i = 0; i < allSpans.length; i++) {
            var sid = parseInt(allSpans[i].dataset.sid);
            if (sid >= startId && sid <= endId) {
                expandedText += allSpans[i].textContent + " ";
            }
        }
        text = expandedText.trim();
    }

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
// All horizontal spacing is computed as exact integers to eliminate subpixel drift
// in WebKit's multi-column layout: marginPx + contentWidth + marginPx == w exactly.
function applyLayout() {
    var w = window.innerWidth;
    var h = window.innerHeight;
    if (w > 0 && h > 0) {
        var root = document.documentElement;
        var marginPct = parseFloat(root.style.getPropertyValue('--raw-margin')) || 0.05;
        var marginPx = Math.floor(w * marginPct);
        var gapPx = marginPx * 2;
        var contentWidth = w - gapPx;
        root.style.setProperty('--user-margin-px', marginPx + 'px');
        root.style.setProperty('--user-gap-px', gapPx + 'px');
        document.body.style.columnWidth = contentWidth + 'px';
        document.body.style.height = h + 'px';
    }
}
function updateStyles(size, color, justify, margin, tbMargin) {
    var root = document.documentElement;
    root.style.setProperty('--user-font-size', size + 'em');
    root.style.setProperty('--user-font-color', color);
    root.style.setProperty('--user-justify', justify);
    root.style.setProperty('--raw-margin', margin);
    root.style.setProperty('--user-tb-margin', Math.floor(tbMargin * 100) + 'vh');
    applyLayout();
}
document.addEventListener('DOMContentLoaded', applyLayout);
window.addEventListener('resize', applyLayout);
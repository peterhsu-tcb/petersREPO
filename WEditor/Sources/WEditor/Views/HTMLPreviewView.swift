import SwiftUI

#if canImport(WebKit)
import WebKit

/// WYSIWYG HTML editor view using WKWebView with contentEditable
struct HTMLPreviewView: NSViewRepresentable {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let userContentController = WKUserContentController()
        // Listen for content changes from JavaScript
        userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Load the HTML content
        loadHTMLContent(in: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if the content actually changed externally (not from our own JS edit)
        if context.coordinator.needsReload {
            context.coordinator.needsReload = false
            loadHTMLContent(in: webView)
        }
    }

    private func loadHTMLContent(in webView: WKWebView) {
        let theme = settings.currentTheme
        let isDark = theme.isDark

        // Wrap the user's HTML in a contentEditable container with editing support
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            * { box-sizing: border-box; }
            html, body {
                margin: 0;
                padding: 0;
                height: 100%;
                background-color: \(isDark ? "#1e1e20" : "#ffffff");
                color: \(isDark ? "#d4d4d4" : "#1e1e1e");
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                font-size: 14px;
            }
            #editor {
                min-height: 100%;
                padding: 16px;
                outline: none;
                overflow-wrap: break-word;
                word-wrap: break-word;
            }
            #editor:focus {
                outline: none;
            }
            /* Basic formatting toolbar styles */
            #toolbar {
                position: sticky;
                top: 0;
                z-index: 100;
                background-color: \(isDark ? "#2d2d30" : "#f0f0f0");
                border-bottom: 1px solid \(isDark ? "#404040" : "#d0d0d0");
                padding: 4px 8px;
                display: flex;
                flex-wrap: wrap;
                gap: 2px;
                align-items: center;
            }
            #toolbar button {
                background: none;
                border: 1px solid transparent;
                border-radius: 4px;
                padding: 4px 8px;
                cursor: pointer;
                font-size: 13px;
                color: \(isDark ? "#cccccc" : "#333333");
                min-width: 28px;
                text-align: center;
            }
            #toolbar button:hover {
                background-color: \(isDark ? "#3e3e42" : "#e0e0e0");
                border-color: \(isDark ? "#555555" : "#c0c0c0");
            }
            #toolbar button:active {
                background-color: \(isDark ? "#505050" : "#d0d0d0");
            }
            #toolbar .separator {
                width: 1px;
                height: 20px;
                background-color: \(isDark ? "#555555" : "#c0c0c0");
                margin: 0 4px;
            }
            /* Table styles */
            #editor table {
                border-collapse: collapse;
                margin: 8px 0;
            }
            #editor table td, #editor table th {
                border: 1px solid \(isDark ? "#555555" : "#c0c0c0");
                padding: 4px 8px;
                min-width: 60px;
            }
            /* Image styles */
            #editor img {
                max-width: 100%;
                height: auto;
            }
            /* Link styles */
            #editor a {
                color: \(isDark ? "#569cd6" : "#0066cc");
            }
            /* Blockquote */
            #editor blockquote {
                border-left: 3px solid \(isDark ? "#555555" : "#c0c0c0");
                margin-left: 0;
                padding-left: 16px;
                color: \(isDark ? "#999999" : "#666666");
            }
            /* Code */
            #editor code {
                background-color: \(isDark ? "#2d2d30" : "#f0f0f0");
                padding: 2px 4px;
                border-radius: 3px;
                font-family: Menlo, Monaco, "Courier New", monospace;
                font-size: 13px;
            }
            #editor pre {
                background-color: \(isDark ? "#1e1e1e" : "#f5f5f5");
                padding: 12px;
                border-radius: 4px;
                overflow-x: auto;
            }
            #editor pre code {
                background: none;
                padding: 0;
            }
        </style>
        </head>
        <body>
        <div id="toolbar">
            <button onclick="execCmd('bold')" title="Bold (⌘B)"><b>B</b></button>
            <button onclick="execCmd('italic')" title="Italic (⌘I)"><i>I</i></button>
            <button onclick="execCmd('underline')" title="Underline (⌘U)"><u>U</u></button>
            <button onclick="execCmd('strikeThrough')" title="Strikethrough"><s>S</s></button>
            <div class="separator"></div>
            <button onclick="execCmd('formatBlock', 'h1')" title="Heading 1">H1</button>
            <button onclick="execCmd('formatBlock', 'h2')" title="Heading 2">H2</button>
            <button onclick="execCmd('formatBlock', 'h3')" title="Heading 3">H3</button>
            <button onclick="execCmd('formatBlock', 'p')" title="Paragraph">P</button>
            <div class="separator"></div>
            <button onclick="execCmd('insertUnorderedList')" title="Bullet List">• List</button>
            <button onclick="execCmd('insertOrderedList')" title="Numbered List">1. List</button>
            <div class="separator"></div>
            <button onclick="execCmd('justifyLeft')" title="Align Left">⫷</button>
            <button onclick="execCmd('justifyCenter')" title="Align Center">⫿</button>
            <button onclick="execCmd('justifyRight')" title="Align Right">⫸</button>
            <div class="separator"></div>
            <button onclick="insertLink()" title="Insert Link">🔗</button>
            <button onclick="execCmd('formatBlock', 'blockquote')" title="Blockquote">❝</button>
            <button onclick="insertHR()" title="Horizontal Rule">—</button>
            <div class="separator"></div>
            <button onclick="execCmd('removeFormat')" title="Clear Formatting">✕</button>
            <button onclick="execCmd('undo')" title="Undo (⌘Z)">↩</button>
            <button onclick="execCmd('redo')" title="Redo (⌘⇧Z)">↪</button>
        </div>
        <div id="editor" contenteditable="true">\(escapeForJS(document.content))</div>
        <script>
            function execCmd(command, value) {
                if (command === 'formatBlock') {
                    document.execCommand(command, false, '<' + value + '>');
                } else {
                    document.execCommand(command, false, value || null);
                }
                notifyChange();
            }

            function insertLink() {
                var url = prompt('Enter URL:', 'https://');
                if (url) {
                    // Validate URL uses a safe protocol
                    try {
                        var parsed = new URL(url);
                        if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:' && parsed.protocol !== 'mailto:') {
                            alert('Only http, https, and mailto URLs are allowed.');
                            return;
                        }
                    } catch (e) {
                        // If URL parsing fails, prepend https:// and retry
                        if (!url.match(/^[a-zA-Z]+:/)) {
                            url = 'https://' + url;
                        } else {
                            alert('Invalid URL.');
                            return;
                        }
                    }
                    document.execCommand('createLink', false, url);
                    notifyChange();
                }
            }

            function insertHR() {
                document.execCommand('insertHorizontalRule', false, null);
                notifyChange();
            }

            var changeTimeout = null;
            function notifyChange() {
                if (changeTimeout) clearTimeout(changeTimeout);
                changeTimeout = setTimeout(function() {
                    var content = document.getElementById('editor').innerHTML;
                    window.webkit.messageHandlers.contentChanged.postMessage(content);
                }, 150);
            }

            var editor = document.getElementById('editor');
            editor.addEventListener('input', notifyChange);
            editor.addEventListener('paste', function() {
                setTimeout(notifyChange, 100);
            });
        </script>
        </body>
        </html>
        """

        webView.loadHTMLString(wrappedHTML, baseURL: document.url?.deletingLastPathComponent())
    }

    /// Escape content for safe embedding in the wrapper HTML template.
    /// Note: The user's HTML content is intentionally rendered — this is a WYSIWYG editor
    /// for local files. We only need to prevent the content from breaking the wrapper template
    /// (e.g., closing our script/body tags prematurely).
    private func escapeForJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "</script>", with: "</scr\\ipt>", options: .caseInsensitive)
            .replacingOccurrences(of: "</body>", with: "</bo\\dy>", options: .caseInsensitive)
            .replacingOccurrences(of: "</html>", with: "</ht\\ml>", options: .caseInsensitive)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var document: Document
        weak var webView: WKWebView?
        var needsReload = false
        private var isUpdatingFromJS = false
        private var lastKnownContent: String = ""

        init(document: Document) {
            self.document = document
            self.lastKnownContent = document.content
            super.init()
        }

        // Handle content changes from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "contentChanged",
                  let htmlContent = message.body as? String else { return }

            // Avoid re-triggering update cycle
            isUpdatingFromJS = true
            lastKnownContent = htmlContent
            document.updateContent(htmlContent)
            isUpdatingFromJS = false
        }

        // Allow navigation for local content only
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                // Open links in system browser
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

/// Container that shows the HTML visual editor with a mode indicator
struct HTMLVisualEditorView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings

    var body: some View {
        VStack(spacing: 0) {
            // Mode bar
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                Text("HTML Visual Editor")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("— Edit the rendered page directly")
                    .font(.system(size: 11))
                    .foregroundColor(settings.currentTheme.textColor.opacity(0.5))
                Spacer()
                Picker("", selection: $document.htmlEditMode) {
                    ForEach(HTMLEditMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(settings.currentTheme.gutterBackgroundColor)

            // WebView editor
            HTMLPreviewView(document: document)
        }
    }
}
#endif

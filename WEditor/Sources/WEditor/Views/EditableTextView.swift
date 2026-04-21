import SwiftUI

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Real editable text view backed by NSTextView, replacing the previous
/// read-only SwiftUI stack. Provides:
///  - Normal mouse/cursor/typing editing
///  - Column-edit mode: plain arrow keys expand the block selection,
///    typing/backspace/delete apply across all selected lines
///  - Drag-and-drop of file URLs to open files as new tabs
struct EditableTextView: NSViewRepresentable {
    @ObservedObject var document: Document
    @ObservedObject var settings: EditorSettings
    @ObservedObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, settings: settings, appState: appState)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage(string: document.content)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let containerSize = NSSize(
            width: settings.wordWrap ? contentSize.width : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.widthTracksTextView = settings.wordWrap
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        let textView = EditorNSTextView(frame: .zero, textContainer: textContainer)
        textView.appState = appState
        textView.coordinator = context.coordinator
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !settings.wordWrap
        textView.autoresizingMask = settings.wordWrap ? [.width] : []
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.smartInsertDeleteEnabled = false
        textView.usesFontPanel = false
        textView.delegate = context.coordinator

        // Register for file URL drops so users can drag files onto the editor.
        textView.registerForDraggedTypes([.fileURL])

        applyTheme(to: textView)
        applyFont(to: textView)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorNSTextView else { return }

        // Keep the coordinator bindings current.
        context.coordinator.document = document
        context.coordinator.settings = settings
        context.coordinator.appState = appState
        textView.appState = appState
        textView.coordinator = context.coordinator

        // Sync document content into the text view if it changed externally
        // (e.g., file was opened, undo/redo from the model, etc.).
        if textView.string != document.content {
            let selected = textView.selectedRange()
            textView.string = document.content
            let safeLocation = min(selected.location, (textView.string as NSString).length)
            textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
        }

        // Word wrap
        if let container = textView.textContainer {
            let contentSize = scrollView.contentSize
            if settings.wordWrap {
                container.widthTracksTextView = true
                container.size = NSSize(width: contentSize.width,
                                        height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                textView.frame.size.width = contentSize.width
            } else {
                container.widthTracksTextView = false
                container.size = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                        height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
            }
        }

        applyTheme(to: textView)
        applyFont(to: textView)
        context.coordinator.applyHighlighting()
    }

    // MARK: - Styling helpers

    private func applyTheme(to textView: NSTextView) {
        let theme = settings.currentTheme
        textView.backgroundColor = NSColor(theme.backgroundColor)
        textView.textColor = NSColor(theme.textColor)
        textView.insertionPointColor = NSColor(theme.textColor)
        textView.drawsBackground = true
    }

    private func applyFont(to textView: NSTextView) {
        let font: NSFont
        if let custom = NSFont(name: settings.fontName, size: settings.fontSize) {
            font = custom
        } else {
            font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        }
        textView.font = font
        textView.typingAttributes[.font] = font
        textView.typingAttributes[.foregroundColor] = NSColor(settings.currentTheme.textColor)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var document: Document
        var settings: EditorSettings
        var appState: AppState
        weak var textView: EditorNSTextView?

        private let highlightingService = SyntaxHighlightingService()
        private var isApplyingHighlighting = false

        init(document: Document, settings: EditorSettings, appState: AppState) {
            self.document = document
            self.settings = settings
            self.appState = appState
        }

        // MARK: Content sync

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newContent = textView.string

            // Write directly into the document without round-tripping through
            // `updateContent` — NSTextView owns its own undo manager, so we
            // don't need to stack duplicate undo records per keystroke.
            document.content = newContent
            document.lines = newContent.components(separatedBy: "\n")
            document.isModified = (document.content != document.originalContent)

            updateCursorFromSelection(in: textView)
            applyHighlighting()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateCursorFromSelection(in: textView)
        }

        private func updateCursorFromSelection(in textView: NSTextView) {
            let nsString = textView.string as NSString
            let range = textView.selectedRange()
            let location = min(range.location, nsString.length)

            // Compute (line, column) by walking prior newlines.
            let prefix = nsString.substring(to: location)
            let lineIndex = prefix.components(separatedBy: "\n").count - 1
            let lastNewline = prefix.range(of: "\n", options: .backwards)
            let column: Int
            if let lastNewline = lastNewline {
                column = prefix.distance(from: lastNewline.upperBound, to: prefix.endIndex)
            } else {
                column = prefix.count
            }

            let newPosition = CursorPosition(line: lineIndex, column: column)
            if document.cursorPosition != newPosition {
                document.cursorPosition = newPosition
            }
        }

        // MARK: Highlighting

        func applyHighlighting() {
            guard let textView = textView,
                  let storage = textView.textStorage else { return }
            if isApplyingHighlighting { return }
            isApplyingHighlighting = true
            defer { isApplyingHighlighting = false }

            let text = textView.string as NSString
            let fullRange = NSRange(location: 0, length: text.length)
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: settings.fontSize,
                                                                    weight: .regular)
            let theme = settings.currentTheme

            storage.beginEditing()
            storage.setAttributes([
                .font: font,
                .foregroundColor: NSColor(theme.textColor)
            ], range: fullRange)

            // Walk the string line by line, tokenizing and applying colors.
            var lineStart = 0
            var lineIndex = 0
            while lineStart <= text.length {
                let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
                let rawLine = text.substring(with: lineRange)
                // Drop the trailing newline, if any, before tokenizing.
                let stripped: String
                if rawLine.hasSuffix("\r\n") {
                    stripped = String(rawLine.dropLast(2))
                } else if rawLine.hasSuffix("\n") || rawLine.hasSuffix("\r") {
                    stripped = String(rawLine.dropLast())
                } else {
                    stripped = rawLine
                }

                let highlighted = highlightingService.highlightLine(stripped,
                                                                    lineIndex: lineIndex,
                                                                    language: document.language)
                for token in highlighted.tokens {
                    let color = theme.color(for: token.tokenType)
                    let absolute = NSRange(location: lineRange.location + token.range.location,
                                           length: token.range.length)
                    guard absolute.location >= 0,
                          absolute.location + absolute.length <= text.length else { continue }
                    storage.addAttribute(.foregroundColor, value: NSColor(color), range: absolute)
                }

                if lineRange.length == 0 { break }
                lineStart = lineRange.location + lineRange.length
                lineIndex += 1
            }
            storage.endEditing()
        }

        // MARK: Drag-and-drop

        /// Returns true when the pasteboard contains file URLs that the
        /// editor should open as documents rather than insert as text.
        func shouldOpenDraggedFiles(_ pboard: NSPasteboard) -> Bool {
            guard let items = pboard.pasteboardItems else { return false }
            return items.contains { $0.types.contains(.fileURL) }
        }

        func openFiles(from pboard: NSPasteboard) -> Bool {
            guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                  !urls.isEmpty else { return false }
            for url in urls {
                appState.openFile(at: url)
            }
            return true
        }
    }
}

/// NSTextView subclass that handles column-edit mode key interception and
/// file-URL drag-and-drop.
final class EditorNSTextView: NSTextView {
    weak var appState: AppState?
    weak var coordinator: EditableTextView.Coordinator?

    // MARK: Column-edit mode key handling

    override func keyDown(with event: NSEvent) {
        if let appState = appState, appState.isColumnEditMode {
            // Arrow keys (no modifiers, or shift) expand the column selection.
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isPlainOrShift = modifiers.isEmpty || modifiers == .shift

            if isPlainOrShift {
                switch event.keyCode {
                case 123: // left
                    appState.expandColumnSelectionLeft()
                    return
                case 124: // right
                    appState.expandColumnSelectionRight()
                    return
                case 125: // down
                    appState.expandColumnSelectionDown()
                    return
                case 126: // up
                    appState.expandColumnSelectionUp()
                    return
                default:
                    break
                }
            }

            // Backspace
            if event.keyCode == 51 {
                appState.columnBackspace()
                return
            }
            // Forward delete
            if event.keyCode == 117 {
                appState.columnDeleteSelection()
                return
            }

            // Typed characters apply across the column selection.
            if let chars = event.characters, !chars.isEmpty,
               !event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.control),
               let first = chars.first,
               first.isASCII,
               (first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol || first == " ") {
                appState.columnTypeText(String(first))
                return
            }
        }

        super.keyDown(with: event)
    }

    // MARK: Drag-and-drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let coord = coordinator, coord.shouldOpenDraggedFiles(sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let coord = coordinator, coord.shouldOpenDraggedFiles(sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let coord = coordinator, coord.shouldOpenDraggedFiles(sender.draggingPasteboard) {
            return true
        }
        return super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let coord = coordinator, coord.shouldOpenDraggedFiles(sender.draggingPasteboard) {
            return coord.openFiles(from: sender.draggingPasteboard)
        }
        return super.performDragOperation(sender)
    }
}
#endif

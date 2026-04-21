import SwiftUI
import AppKit

/// Wraps an `NSTextView` inside SwiftUI to give us native AppKit text editing
/// (undo, IME, find ring, etc.). Column mode is rendered as an overlay tint
/// on top of the text view; the underlying storage is unchanged.
struct TextEditorView: NSViewRepresentable {
    @ObservedObject var document: Document
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.font = NSFont(name: state.fontName, size: state.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: state.fontSize, weight: .regular)
        tv.delegate = context.coordinator
        tv.string = document.text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != document.text {
            tv.string = document.text
        }
        let desiredFont = NSFont(name: state.fontName, size: state.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: state.fontSize, weight: .regular)
        if tv.font != desiredFont {
            tv.font = desiredFont
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let document: Document
        init(document: Document) { self.document = document }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            // Avoid round-tripping through `setText` (which re-encodes bytes
            // on every keystroke). Update in place; bytes are recomputed on save.
            document.text = tv.string
            document.isDirty = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            document.cursor = tv.selectedRange.location
            document.selection = tv.selectedRange
        }
    }
}

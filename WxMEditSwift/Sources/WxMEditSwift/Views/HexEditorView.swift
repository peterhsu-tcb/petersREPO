import SwiftUI
import AppKit

/// Read-only hex/ASCII viewer (with editable raw-hex pane). The bytes shown
/// are exactly `document.bytes`. Editing the hex pane parses and writes back
/// to the document's byte buffer, then re-decodes into `text`.
struct HexEditorView: NSViewRepresentable {
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
        tv.font = NSFont.monospacedSystemFont(ofSize: state.fontSize, weight: .regular)
        tv.delegate = context.coordinator
        tv.string = HexService.render(document.bytes, bytesPerRow: state.hexBytesPerRow)
        // The rendered hex view is read-only by default; users edit by typing
        // hex into the find-replace bar or using `Edit > Edit Hex…` (TODO).
        tv.isEditable = false
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        let rendered = HexService.render(document.bytes, bytesPerRow: state.hexBytesPerRow)
        if tv.string != rendered {
            tv.string = rendered
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let document: Document
        init(document: Document) { self.document = document }
    }
}

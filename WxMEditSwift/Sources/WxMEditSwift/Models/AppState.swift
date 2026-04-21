import Foundation
import Combine

/// Top-level application state. Holds the open documents and the currently
/// active one, plus global settings that aren't persisted with the document.
public final class AppState: ObservableObject {
    @Published public var documents: [Document] = []
    @Published public var activeDocumentID: UUID?

    @Published public var fontName: String = "Menlo"
    @Published public var fontSize: CGFloat = 13
    @Published public var hexBytesPerRow: Int = 16
    @Published public var showFindBar: Bool = false

    public init() {
        // Start with one empty document so the UI has something to show.
        let doc = Document()
        documents = [doc]
        activeDocumentID = doc.id
    }

    public var activeDocument: Document? {
        guard let id = activeDocumentID else { return nil }
        return documents.first { $0.id == id }
    }

    public func newDocument() {
        let doc = Document()
        documents.append(doc)
        activeDocumentID = doc.id
    }

    public func closeDocument(_ id: UUID) {
        documents.removeAll { $0.id == id }
        if activeDocumentID == id {
            activeDocumentID = documents.first?.id
        }
        if documents.isEmpty {
            newDocument()
        }
    }

    public func addDocument(_ doc: Document) {
        documents.append(doc)
        activeDocumentID = doc.id
    }
}

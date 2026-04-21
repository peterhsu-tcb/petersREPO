import Foundation
import Combine

/// A single open document in the editor.
///
/// Holds both the textual representation (used by Text and Column modes)
/// and the raw byte representation (used by Hex mode). The two are kept in
/// sync through `setText(_:)` and `setBytes(_:)`.
public final class Document: ObservableObject, Identifiable {
    public let id = UUID()

    @Published public var url: URL?
    @Published public var text: String
    @Published public var bytes: Data
    @Published public var encoding: TextEncoding
    @Published public var lineEnding: LineEnding
    @Published public var mode: EditMode = .text
    @Published public var isDirty: Bool = false

    /// Linear cursor offset in `text` (UTF-16 code units, matching NSTextView).
    @Published public var cursor: Int = 0

    /// Linear selection range in `text` (UTF-16 code units).
    @Published public var selection: NSRange = NSRange(location: 0, length: 0)

    /// Rectangular selection used in column mode: `(startLine, endLine, startColumn, endColumn)`.
    @Published public var columnSelection: ColumnRect?

    /// Cursor offset in bytes for hex mode.
    @Published public var hexCursor: Int = 0

    public init(url: URL? = nil,
                text: String = "",
                bytes: Data = Data(),
                encoding: TextEncoding = .utf8,
                lineEnding: LineEnding = .lf) {
        self.url = url
        self.text = text
        self.bytes = bytes
        self.encoding = encoding
        self.lineEnding = lineEnding
    }

    /// Display name shown on the tab and the title bar.
    public var displayName: String {
        url?.lastPathComponent ?? "Untitled"
    }

    /// Replace the textual content and re-encode to keep `bytes` in sync.
    public func setText(_ newText: String) {
        text = newText
        bytes = (newText.data(using: encoding.stringEncoding) ?? Data())
        if let bom = encoding.bom { bytes = bom + bytes }
        isDirty = true
    }

    /// Replace raw bytes and decode to keep `text` in sync. Falls back to a
    /// best-effort decode (Latin-1) if the chosen encoding cannot decode.
    public func setBytes(_ newBytes: Data) {
        bytes = newBytes
        let stripped = stripBOM(newBytes, for: encoding)
        if let decoded = String(data: stripped, encoding: encoding.stringEncoding) {
            text = decoded
        } else if let fallback = String(data: stripped, encoding: .isoLatin1) {
            text = fallback
        } else {
            text = ""
        }
        isDirty = true
    }

    private func stripBOM(_ data: Data, for encoding: TextEncoding) -> Data {
        guard let bom = encoding.bom, data.starts(with: bom) else { return data }
        return data.dropFirst(bom.count)
    }
}

/// A rectangular selection used in column mode.
public struct ColumnRect: Equatable {
    public var startLine: Int
    public var endLine: Int
    public var startColumn: Int
    public var endColumn: Int

    public init(startLine: Int, endLine: Int, startColumn: Int, endColumn: Int) {
        self.startLine = startLine
        self.endLine = endLine
        self.startColumn = startColumn
        self.endColumn = endColumn
    }

    public var normalized: ColumnRect {
        ColumnRect(
            startLine:   min(startLine, endLine),
            endLine:     max(startLine, endLine),
            startColumn: min(startColumn, endColumn),
            endColumn:   max(startColumn, endColumn)
        )
    }
}

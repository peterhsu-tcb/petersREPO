import Foundation

/// Loads and saves documents from disk, performing encoding detection
/// (BOM-based, with a fallback heuristic) similar to wxMEdit.
public enum FileService {
    public enum Error: Swift.Error {
        case readFailed(URL, Swift.Error)
        case writeFailed(URL, Swift.Error)
        case decodeFailed(URL, TextEncoding)
    }

    /// Read a file from disk, returning a fully-populated `Document`.
    public static func open(_ url: URL,
                            preferred: TextEncoding? = nil) throws -> Document {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw Error.readFailed(url, error)
        }

        let detected = preferred
            ?? TextEncoding.detectBOM(in: data)
            ?? heuristicEncoding(for: data)

        let payload: Data
        if let bom = detected.bom, data.starts(with: bom) {
            payload = data.dropFirst(bom.count)
        } else {
            payload = data
        }

        let text: String
        if let s = String(data: payload, encoding: detected.stringEncoding) {
            text = s
        } else if let s = String(data: payload, encoding: .isoLatin1) {
            // Last-resort: Latin-1 decodes any byte sequence without loss.
            text = s
        } else {
            throw Error.decodeFailed(url, detected)
        }

        let lineEnding = LineEnding.detect(in: text)
        let doc = Document(
            url: url,
            text: text,
            bytes: data,
            encoding: detected,
            lineEnding: lineEnding
        )
        doc.isDirty = false
        return doc
    }

    /// Write a document to disk. Uses `document.url` if `to` is nil.
    public static func save(_ document: Document, to url: URL? = nil) throws {
        guard let target = url ?? document.url else { return }

        let normalized = document.lineEnding.normalize(document.text)
        var data = normalized.data(using: document.encoding.stringEncoding) ?? Data()
        if let bom = document.encoding.bom {
            data = bom + data
        }

        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw Error.writeFailed(target, error)
        }

        document.url = target
        document.bytes = data
        document.isDirty = false
    }

    /// Very small heuristic that picks UTF-8 if the bytes are valid UTF-8,
    /// otherwise Windows-1252. wxMEdit ships a much richer detector but
    /// this is a reasonable default for a starter implementation.
    static func heuristicEncoding(for data: Data) -> TextEncoding {
        if String(data: data, encoding: .utf8) != nil {
            return .utf8
        }
        return .windows1252
    }
}

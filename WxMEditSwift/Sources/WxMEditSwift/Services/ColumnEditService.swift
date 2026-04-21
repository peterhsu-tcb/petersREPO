import Foundation

/// Implements wxMEdit's "column edit mode" operations on a plain string:
/// rectangular insert, delete, fill, and extract.
///
/// Lines are split on "\n" — callers should normalize line endings first
/// using `LineEnding.normalize(_:)`.
public enum ColumnEditService {

    /// Extract the rectangular region described by `rect` from `text`.
    /// Returns one entry per selected line, padded with spaces if the line
    /// is shorter than `rect.endColumn`.
    public static func extract(_ text: String, rect: ColumnRect) -> [String] {
        let r = rect.normalized
        let lines = split(text)
        var out: [String] = []
        for i in r.startLine...min(r.endLine, lines.count - 1) where i >= 0 {
            out.append(slice(lines[i], from: r.startColumn, to: r.endColumn))
        }
        return out
    }

    /// Delete the rectangular region from `text`, returning the new string.
    public static func delete(_ text: String, rect: ColumnRect) -> String {
        let r = rect.normalized
        var lines = split(text)
        for i in r.startLine...min(r.endLine, lines.count - 1) where i >= 0 {
            lines[i] = remove(lines[i], from: r.startColumn, to: r.endColumn)
        }
        return lines.joined(separator: "\n")
    }

    /// Insert `value` at `column` on every line in `lineRange`.
    /// Lines shorter than `column` are right-padded with spaces.
    public static func insert(_ text: String,
                              value: String,
                              at column: Int,
                              lines lineRange: ClosedRange<Int>) -> String {
        var lines = split(text)
        for i in lineRange where i >= 0 && i < lines.count {
            let head = takePrefix(lines[i], width: column)
            lines[i] = head + value + suffix(of: lines[i], from: column)
        }
        return lines.joined(separator: "\n")
    }

    /// Fill the rectangular region with the single character `char`.
    public static func fill(_ text: String, rect: ColumnRect, with char: Character) -> String {
        let r = rect.normalized
        let width = max(0, r.endColumn - r.startColumn)
        let block = String(repeating: String(char), count: width)
        var lines = split(text)
        for i in r.startLine...min(r.endLine, lines.count - 1) where i >= 0 {
            let head = takePrefix(lines[i], width: r.startColumn)
            let tail = self.suffix(of: lines[i], from: r.endColumn)
            lines[i] = head + block + tail
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - private helpers

    static func split(_ text: String) -> [String] {
        // Preserve trailing empty line if the text ends in "\n".
        return text.components(separatedBy: "\n")
    }

    /// Returns the first `width` characters of `line`, right-padded with
    /// spaces if the line is shorter than `width`.
    static func takePrefix(_ line: String, width: Int) -> String {
        if width <= 0 { return "" }
        if line.count >= width {
            let upper = line.index(line.startIndex, offsetBy: width)
            return String(line[..<upper])
        }
        return line + String(repeating: " ", count: width - line.count)
    }

    static func slice(_ line: String, from start: Int, to end: Int) -> String {
        let padded = pad(line, to: end)
        let lower = padded.index(padded.startIndex, offsetBy: max(0, start))
        let upper = padded.index(padded.startIndex, offsetBy: max(0, end))
        return String(padded[lower..<upper])
    }

    static func remove(_ line: String, from start: Int, to end: Int) -> String {
        guard start < end else { return line }
        let count = line.count
        if start >= count { return line }
        let lower = line.index(line.startIndex, offsetBy: start)
        let upper = line.index(line.startIndex, offsetBy: min(end, count))
        var result = line
        result.removeSubrange(lower..<upper)
        return result
    }

    static func pad(_ line: String, to width: Int) -> String {
        if line.count >= width { return line }
        return line + String(repeating: " ", count: width - line.count)
    }

    static func suffix(of line: String, from column: Int) -> String {
        if column >= line.count { return "" }
        let idx = line.index(line.startIndex, offsetBy: column)
        return String(line[idx...])
    }
}

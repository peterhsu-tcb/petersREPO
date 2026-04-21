import Foundation

/// Line-ending styles, mirroring wxMEdit's ability to display and convert
/// between Unix (LF), classic Mac (CR), and DOS/Windows (CRLF) line endings.
public enum LineEnding: String, CaseIterable, Identifiable, Codable {
    case lf   = "LF"     // Unix, modern macOS
    case crlf = "CRLF"   // Windows
    case cr   = "CR"     // Classic Mac

    public var id: String { rawValue }

    public var sequence: String {
        switch self {
        case .lf:   return "\n"
        case .crlf: return "\r\n"
        case .cr:   return "\r"
        }
    }

    /// Detects the dominant line ending in a string. Defaults to `.lf` if none found.
    public static func detect(in text: String) -> LineEnding {
        var lf = 0, cr = 0, crlf = 0
        var iterator = text.unicodeScalars.makeIterator()
        var prev: Unicode.Scalar? = nil
        while let s = iterator.next() {
            if s == "\n" {
                if prev == "\r" { crlf += 1; cr -= 1 } else { lf += 1 }
            } else if s == "\r" {
                cr += 1
            }
            prev = s
        }
        if crlf >= lf && crlf >= cr { return .crlf }
        if cr   >  lf                { return .cr }
        return .lf
    }

    /// Normalize all line endings in `text` to this style.
    public func normalize(_ text: String) -> String {
        // First fold to LF, then expand to target sequence.
        let lfOnly = text.replacingOccurrences(of: "\r\n", with: "\n")
                         .replacingOccurrences(of: "\r",   with: "\n")
        if self == .lf { return lfOnly }
        return lfOnly.replacingOccurrences(of: "\n", with: sequence)
    }
}

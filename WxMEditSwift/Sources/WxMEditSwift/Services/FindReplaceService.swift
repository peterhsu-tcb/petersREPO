import Foundation

/// Find/replace logic shared by both text and hex modes.
///
/// `find(in:options:from:)` returns the next match (wrapping around if needed),
/// expressed as a UTF-16 `NSRange` to interoperate with NSTextView. Hex mode
/// callers can convert byte offsets to a "decoded as Latin-1" string for use
/// with the same engine.
public enum FindReplaceService {

    public struct Options {
        public var caseSensitive: Bool
        public var wholeWord: Bool
        public var regex: Bool
        public var wrap: Bool

        public init(caseSensitive: Bool = false,
                    wholeWord: Bool = false,
                    regex: Bool = false,
                    wrap: Bool = true) {
            self.caseSensitive = caseSensitive
            self.wholeWord = wholeWord
            self.regex = regex
            self.wrap = wrap
        }
    }

    /// Find the next match of `pattern` in `text`, starting at UTF-16 offset `from`.
    /// Returns `nil` if no match exists (and `options.wrap` is false or the whole
    /// string was searched).
    public static func find(_ pattern: String,
                            in text: String,
                            options: Options = Options(),
                            from: Int = 0) -> NSRange? {
        guard !pattern.isEmpty else { return nil }
        let ns = text as NSString
        let total = ns.length
        let start = max(0, min(from, total))

        let regex: NSRegularExpression
        do {
            regex = try buildRegex(pattern: pattern, options: options)
        } catch {
            return nil
        }

        let tail = NSRange(location: start, length: total - start)
        if let m = regex.firstMatch(in: text, options: [], range: tail) {
            return m.range
        }
        if options.wrap, start > 0 {
            let head = NSRange(location: 0, length: start)
            return regex.firstMatch(in: text, options: [], range: head)?.range
        }
        return nil
    }

    /// Replace every match of `pattern` in `text` with `replacement`.
    /// Returns the new string and the number of replacements made.
    public static func replaceAll(_ pattern: String,
                                  with replacement: String,
                                  in text: String,
                                  options: Options = Options()) -> (String, Int) {
        guard !pattern.isEmpty else { return (text, 0) }
        let regex: NSRegularExpression
        do {
            regex = try buildRegex(pattern: pattern, options: options)
        } catch {
            return (text, 0)
        }
        let range = NSRange(location: 0, length: (text as NSString).length)
        let template = options.regex
            ? replacement
            : NSRegularExpression.escapedTemplate(for: replacement)
        let count = regex.numberOfMatches(in: text, options: [], range: range)
        let out = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
        return (out, count)
    }

    static func buildRegex(pattern: String, options: Options) throws -> NSRegularExpression {
        var opts: NSRegularExpression.Options = []
        if !options.caseSensitive { opts.insert(.caseInsensitive) }

        var pat = options.regex ? pattern : NSRegularExpression.escapedPattern(for: pattern)
        if options.wholeWord {
            pat = "\\b" + pat + "\\b"
        }
        return try NSRegularExpression(pattern: pat, options: opts)
    }
}

import Foundation

/// Hex-mode utilities. Converts between raw bytes and the canonical
/// "offset | hex bytes | ascii" rendering wxMEdit shows in hex view.
public enum HexService {
    /// Render `data` as wxMEdit-style hex rows.
    ///
    ///   00000000  48 65 6C 6C 6F 20 57 6F  72 6C 64 21 0A           Hello Wo rld!.
    ///
    /// - Parameters:
    ///   - data: bytes to render
    ///   - bytesPerRow: usually 16
    /// - Returns: a string with one row per line, no trailing newline.
    public static func render(_ data: Data, bytesPerRow: Int = 16) -> String {
        precondition(bytesPerRow > 0, "bytesPerRow must be positive")
        var lines: [String] = []
        lines.reserveCapacity((data.count + bytesPerRow - 1) / bytesPerRow)

        var offset = 0
        while offset < data.count {
            let end = min(offset + bytesPerRow, data.count)
            let slice = data[offset..<end]
            lines.append(formatRow(offset: offset, bytes: slice, bytesPerRow: bytesPerRow))
            offset = end
        }
        return lines.joined(separator: "\n")
    }

    static func formatRow(offset: Int, bytes: Data.SubSequence, bytesPerRow: Int) -> String {
        let offsetString = String(format: "%08X", offset)

        var hexParts: [String] = []
        hexParts.reserveCapacity(bytesPerRow)
        var asciiChars: [Character] = []
        asciiChars.reserveCapacity(bytesPerRow)

        for i in 0..<bytesPerRow {
            let idx = bytes.startIndex + i
            if idx < bytes.endIndex {
                let b = bytes[idx]
                hexParts.append(String(format: "%02X", b))
                asciiChars.append(isPrintable(b) ? Character(UnicodeScalar(b)) : ".")
            } else {
                hexParts.append("  ")
                asciiChars.append(" ")
            }
        }

        // Group hex bytes in two halves of 8 for readability (wxMEdit style).
        let half = bytesPerRow / 2
        let firstHalf = hexParts.prefix(half).joined(separator: " ")
        let secondHalf = hexParts.suffix(bytesPerRow - half).joined(separator: " ")
        let hexColumn = secondHalf.isEmpty ? firstHalf : "\(firstHalf)  \(secondHalf)"

        return "\(offsetString)  \(hexColumn)  \(String(asciiChars))"
    }

    static func isPrintable(_ byte: UInt8) -> Bool {
        return byte >= 0x20 && byte < 0x7F
    }

    /// Parse a hex string ("DE AD BE EF" or "deadbeef") into raw bytes.
    /// Returns nil if any non-hex characters remain after stripping whitespace.
    public static func parseHex(_ string: String) -> Data? {
        let cleaned = string.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard cleaned.count % 2 == 0 else { return nil }
        var out = Data()
        out.reserveCapacity(cleaned.count / 2)
        var iterator = cleaned.makeIterator()
        while let hi = iterator.next(), let lo = iterator.next() {
            guard let h = hexValue(hi), let l = hexValue(lo) else { return nil }
            out.append(UInt8(h << 4 | l))
        }
        return out
    }

    private static func hexValue(_ scalar: Unicode.Scalar) -> UInt8? {
        switch scalar {
        case "0"..."9": return UInt8(scalar.value - Unicode.Scalar("0").value)
        case "a"..."f": return UInt8(scalar.value - Unicode.Scalar("a").value + 10)
        case "A"..."F": return UInt8(scalar.value - Unicode.Scalar("A").value + 10)
        default:        return nil
        }
    }

    /// Replace `count` bytes starting at `offset` with `replacement`. Pads
    /// with zeros if `offset` is past the end.
    public static func replaceBytes(in data: inout Data,
                                    offset: Int,
                                    count: Int,
                                    with replacement: Data) {
        if offset > data.count {
            data.append(Data(repeating: 0, count: offset - data.count))
        }
        let end = min(offset + count, data.count)
        let range = offset..<end
        data.replaceSubrange(range, with: replacement)
    }
}

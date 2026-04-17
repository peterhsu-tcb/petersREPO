import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// Count occurrences of a substring
    func countOccurrences(of substring: String, caseSensitive: Bool = true) -> Int {
        if caseSensitive {
            return components(separatedBy: substring).count - 1
        } else {
            return lowercased().components(separatedBy: substring.lowercased()).count - 1
        }
    }
    
    /// Get line and column from character offset
    func lineAndColumn(at offset: Int) -> (line: Int, column: Int) {
        var line = 0
        var column = 0
        var currentOffset = 0
        
        for char in self {
            if currentOffset == offset {
                return (line, column)
            }
            if char == "\n" {
                line += 1
                column = 0
            } else {
                column += 1
            }
            currentOffset += 1
        }
        
        return (line, column)
    }
    
    /// Get character offset from line and column
    func offset(atLine line: Int, column: Int) -> Int {
        var currentLine = 0
        var offset = 0
        
        for char in self {
            if currentLine == line {
                if column == 0 { return offset }
                break
            }
            if char == "\n" {
                currentLine += 1
            }
            offset += 1
        }
        
        return offset + column
    }
    
    /// Check if string is a valid filename
    var isValidFilename: Bool {
        !isEmpty &&
        self != "." &&
        self != ".." &&
        !contains("/") &&
        !contains("\\") &&
        !contains(":") &&
        !contains("\0")
    }
    
    /// Truncate string to length with ellipsis
    func truncated(to length: Int) -> String {
        if count <= length { return self }
        return String(prefix(length - 1)) + "…"
    }
}

// MARK: - NSFont Extensions (for macOS)

#if canImport(AppKit)
import AppKit

extension NSFont {
    /// Create a monospaced font
    static func monospacedFont(name: String, size: CGFloat) -> NSFont {
        if let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
    
    /// Character width for monospaced font
    var characterWidth: CGFloat {
        let attributedString = NSAttributedString(string: "M", attributes: [.font: self])
        return attributedString.size().width
    }
    
    /// Line height for the font
    var lineHeight: CGFloat {
        return ascender - descender + leading
    }
}
#endif

// MARK: - Color Extensions

extension Color {
    /// Create color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript access
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Int Extensions

extension Int {
    /// Format as line number with padding
    func lineNumberString(totalLines: Int) -> String {
        let digits = String(totalLines).count
        return String(format: "%\(digits)d", self)
    }
}

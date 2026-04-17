import Foundation
import SwiftUI

/// A highlighted token in the text
struct HighlightedToken: Identifiable {
    let id = UUID()
    let range: NSRange
    let tokenType: TokenType
    let text: String
}

/// A line with its highlighted tokens
struct HighlightedLine {
    let lineIndex: Int
    let text: String
    let tokens: [HighlightedToken]
}

/// Service for performing syntax highlighting
class SyntaxHighlightingService {
    
    private var cachedRegexes: [String: NSRegularExpression] = [:]
    
    /// Highlight a single line of text
    func highlightLine(_ text: String, lineIndex: Int, language: SyntaxLanguage) -> HighlightedLine {
        let definition = SyntaxDefinition.definition(for: language)
        var tokens: [HighlightedToken] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        // Track highlighted ranges to avoid overlapping
        var highlightedRanges: [NSRange] = []
        
        for rule in definition.rules {
            guard let regex = getRegex(pattern: rule.pattern, options: rule.options) else { continue }
            
            let matches = regex.matches(in: text, options: [], range: fullRange)
            
            for match in matches {
                let matchRange = match.range
                
                // Skip if this range overlaps with an already highlighted range
                if highlightedRanges.contains(where: { NSIntersectionRange($0, matchRange).length > 0 }) {
                    continue
                }
                
                let matchText = nsText.substring(with: matchRange)
                tokens.append(HighlightedToken(
                    range: matchRange,
                    tokenType: rule.tokenType,
                    text: matchText
                ))
                highlightedRanges.append(matchRange)
            }
        }
        
        // Sort tokens by position
        tokens.sort { $0.range.location < $1.range.location }
        
        return HighlightedLine(lineIndex: lineIndex, text: text, tokens: tokens)
    }
    
    /// Highlight multiple lines
    func highlightLines(_ lines: [String], language: SyntaxLanguage) -> [HighlightedLine] {
        return lines.enumerated().map { index, line in
            highlightLine(line, lineIndex: index, language: language)
        }
    }
    
    /// Highlight a range of lines (for incremental highlighting)
    func highlightRange(lines: [String], startLine: Int, endLine: Int, language: SyntaxLanguage) -> [HighlightedLine] {
        let start = max(0, startLine)
        let end = min(lines.count - 1, endLine)
        
        guard start <= end else { return [] }
        
        return (start...end).map { index in
            highlightLine(lines[index], lineIndex: index, language: language)
        }
    }
    
    /// Get or create cached regex
    private func getRegex(pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        let key = "\(pattern)_\(options.rawValue)"
        
        if let cached = cachedRegexes[key] {
            return cached
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            cachedRegexes[key] = regex
            return regex
        } catch {
            return nil
        }
    }
    
    /// Build an attributed string for a highlighted line
    func attributedString(for highlightedLine: HighlightedLine, theme: EditorTheme, font: NSFont) -> NSAttributedString {
        let text = highlightedLine.text
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor(theme.textColor),
                .font: font
            ]
        )
        
        for token in highlightedLine.tokens {
            let color = theme.color(for: token.tokenType)
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(color)
            ]
            
            // Apply bold for keywords and headings
            if token.tokenType == .keyword || token.tokenType == .heading || token.tokenType == .bold {
                attributes[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.bold), size: font.pointSize) ?? font
            }
            
            // Apply italic for comments and italic tokens
            if token.tokenType == .comment || token.tokenType == .italic {
                attributes[.font] = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.italic), size: font.pointSize) ?? font
            }
            
            attributedString.addAttributes(attributes, range: token.range)
        }
        
        return attributedString
    }
    
    /// Clear regex cache
    func clearCache() {
        cachedRegexes.removeAll()
    }
}

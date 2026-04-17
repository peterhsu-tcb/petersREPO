import Foundation

/// Search match result
struct SearchMatch: Identifiable, Equatable {
    let id = UUID()
    let line: Int
    let column: Int
    let length: Int
    let matchText: String
    
    static func == (lhs: SearchMatch, rhs: SearchMatch) -> Bool {
        return lhs.line == rhs.line && lhs.column == rhs.column && lhs.length == rhs.length
    }
}

/// Search options
struct SearchOptions {
    var caseSensitive: Bool = false
    var wholeWord: Bool = false
    var useRegex: Bool = false
    var wrapAround: Bool = true
    var searchInSelection: Bool = false
}

/// Search and replace service
class SearchReplaceService {
    
    /// Find all matches in the document
    func findAll(in lines: [String], searchText: String, options: SearchOptions) -> [SearchMatch] {
        guard !searchText.isEmpty else { return [] }
        
        var matches: [SearchMatch] = []
        
        let pattern = buildPattern(searchText: searchText, options: options)
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: options.caseSensitive ? [] : [.caseInsensitive]
        ) else { return [] }
        
        for (lineIndex, line) in lines.enumerated() {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            let lineMatches = regex.matches(in: line, options: [], range: range)
            
            for match in lineMatches {
                let matchText = nsLine.substring(with: match.range)
                matches.append(SearchMatch(
                    line: lineIndex,
                    column: match.range.location,
                    length: match.range.length,
                    matchText: matchText
                ))
            }
        }
        
        return matches
    }
    
    /// Find next match from a given position
    func findNext(in lines: [String], searchText: String, fromLine: Int, fromColumn: Int, options: SearchOptions) -> SearchMatch? {
        let allMatches = findAll(in: lines, searchText: searchText, options: options)
        
        // Find the first match after the current position
        if let match = allMatches.first(where: {
            $0.line > fromLine || ($0.line == fromLine && $0.column > fromColumn)
        }) {
            return match
        }
        
        // Wrap around
        if options.wrapAround {
            return allMatches.first
        }
        
        return nil
    }
    
    /// Find previous match from a given position
    func findPrevious(in lines: [String], searchText: String, fromLine: Int, fromColumn: Int, options: SearchOptions) -> SearchMatch? {
        let allMatches = findAll(in: lines, searchText: searchText, options: options)
        
        // Find the last match before the current position
        if let match = allMatches.last(where: {
            $0.line < fromLine || ($0.line == fromLine && $0.column < fromColumn)
        }) {
            return match
        }
        
        // Wrap around
        if options.wrapAround {
            return allMatches.last
        }
        
        return nil
    }
    
    /// Replace a single match
    func replace(in lines: inout [String], match: SearchMatch, replacement: String) {
        guard match.line < lines.count else { return }
        
        var line = lines[match.line]
        let nsLine = line as NSString
        
        guard match.column + match.length <= nsLine.length else { return }
        
        let range = NSRange(location: match.column, length: match.length)
        line = nsLine.replacingCharacters(in: range, with: replacement)
        lines[match.line] = line
    }
    
    /// Replace all matches
    func replaceAll(in lines: inout [String], searchText: String, replacement: String, options: SearchOptions) -> Int {
        let matches = findAll(in: lines, searchText: searchText, options: options)
        
        // Process matches from end to start to maintain correct positions
        var count = 0
        for match in matches.reversed() {
            replace(in: &lines, match: match, replacement: replacement)
            count += 1
        }
        
        return count
    }
    
    /// Build regex pattern from search text and options
    private func buildPattern(searchText: String, options: SearchOptions) -> String {
        var pattern: String
        
        if options.useRegex {
            pattern = searchText
        } else {
            pattern = NSRegularExpression.escapedPattern(for: searchText)
        }
        
        if options.wholeWord {
            pattern = "\\b\(pattern)\\b"
        }
        
        return pattern
    }
}

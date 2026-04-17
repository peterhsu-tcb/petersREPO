import Foundation

/// Column edit operation types
enum ColumnEditOperation {
    case insert(String)
    case delete
    case replace(String)
    case paste([String])
}

/// Service for column (block) editing operations
class ColumnEditService {
    
    /// Extract text from a column selection
    func extractColumnText(from lines: [String], selection: ColumnSelection) -> [String] {
        var result: [String] = []
        
        for lineIndex in selection.topLine...selection.bottomLine {
            guard lineIndex < lines.count else {
                result.append("")
                continue
            }
            
            let line = lines[lineIndex]
            let lineLength = line.count
            
            if selection.leftColumn >= lineLength {
                result.append("")
            } else {
                let startIdx = line.index(line.startIndex, offsetBy: selection.leftColumn)
                let endOffset = min(selection.rightColumn, lineLength)
                let endIdx = line.index(line.startIndex, offsetBy: endOffset)
                result.append(String(line[startIdx..<endIdx]))
            }
        }
        
        return result
    }
    
    /// Insert text at a column position across multiple lines
    func insertColumn(in lines: inout [String], text: String, selection: ColumnSelection) {
        for lineIndex in selection.topLine...selection.bottomLine {
            guard lineIndex < lines.count else { continue }
            
            var line = lines[lineIndex]
            let insertColumn = selection.leftColumn
            
            // Pad line if necessary
            if line.count < insertColumn {
                line += String(repeating: " ", count: insertColumn - line.count)
            }
            
            let insertIdx = line.index(line.startIndex, offsetBy: insertColumn)
            line.insert(contentsOf: text, at: insertIdx)
            lines[lineIndex] = line
        }
    }
    
    /// Delete text in a column selection
    func deleteColumn(in lines: inout [String], selection: ColumnSelection) {
        for lineIndex in selection.topLine...selection.bottomLine {
            guard lineIndex < lines.count else { continue }
            
            let line = lines[lineIndex]
            let lineLength = line.count
            
            guard selection.leftColumn < lineLength else { continue }
            
            let startIdx = line.index(line.startIndex, offsetBy: selection.leftColumn)
            let endOffset = min(selection.rightColumn, lineLength)
            let endIdx = line.index(line.startIndex, offsetBy: endOffset)
            
            var mutableLine = line
            mutableLine.removeSubrange(startIdx..<endIdx)
            lines[lineIndex] = mutableLine
        }
    }
    
    /// Replace text in a column selection
    func replaceColumn(in lines: inout [String], selection: ColumnSelection, replacement: String) {
        deleteColumn(in: &lines, selection: selection)
        insertColumn(in: &lines, text: replacement, selection: selection)
    }
    
    /// Paste column text (multiple lines) at a column position
    func pasteColumn(in lines: inout [String], pasteLines: [String], startLine: Int, startColumn: Int) {
        for (offset, pasteText) in pasteLines.enumerated() {
            let lineIndex = startLine + offset
            
            // Add new lines if needed
            while lineIndex >= lines.count {
                lines.append("")
            }
            
            var line = lines[lineIndex]
            
            // Pad line if necessary
            if line.count < startColumn {
                line += String(repeating: " ", count: startColumn - line.count)
            }
            
            let insertIdx = line.index(line.startIndex, offsetBy: startColumn)
            line.insert(contentsOf: pasteText, at: insertIdx)
            lines[lineIndex] = line
        }
    }
    
    /// Move column selection up
    func moveColumnUp(in lines: inout [String], selection: inout ColumnSelection) {
        guard selection.topLine > 0 else { return }
        
        let columnText = extractColumnText(from: lines, selection: selection)
        deleteColumn(in: &lines, selection: selection)
        
        let movedSelection = ColumnSelection(
            startLine: selection.startLine - 1,
            startColumn: selection.startColumn,
            endLine: selection.endLine - 1,
            endColumn: selection.endColumn
        )
        
        pasteColumn(in: &lines, pasteLines: columnText, startLine: movedSelection.topLine, startColumn: movedSelection.leftColumn)
        selection = movedSelection
    }
    
    /// Move column selection down
    func moveColumnDown(in lines: inout [String], selection: inout ColumnSelection) {
        guard selection.bottomLine < lines.count - 1 else { return }
        
        let columnText = extractColumnText(from: lines, selection: selection)
        deleteColumn(in: &lines, selection: selection)
        
        let movedSelection = ColumnSelection(
            startLine: selection.startLine + 1,
            startColumn: selection.startColumn,
            endLine: selection.endLine + 1,
            endColumn: selection.endColumn
        )
        
        pasteColumn(in: &lines, pasteLines: columnText, startLine: movedSelection.topLine, startColumn: movedSelection.leftColumn)
        selection = movedSelection
    }
    
    /// Fill column selection with a character
    func fillColumn(in lines: inout [String], selection: ColumnSelection, character: Character) {
        let fillText = String(repeating: character, count: selection.width)
        replaceColumn(in: &lines, selection: selection, replacement: fillText)
    }
    
    /// Indent column selection
    func indentColumn(in lines: inout [String], selection: ColumnSelection, indentString: String) {
        for lineIndex in selection.topLine...selection.bottomLine {
            guard lineIndex < lines.count else { continue }
            
            var line = lines[lineIndex]
            let insertIdx = line.index(line.startIndex, offsetBy: min(selection.leftColumn, line.count))
            line.insert(contentsOf: indentString, at: insertIdx)
            lines[lineIndex] = line
        }
    }
    
    /// Unindent column selection
    func unindentColumn(in lines: inout [String], selection: ColumnSelection, indentString: String) {
        for lineIndex in selection.topLine...selection.bottomLine {
            guard lineIndex < lines.count else { continue }
            
            let line = lines[lineIndex]
            if line.hasPrefix(indentString) {
                lines[lineIndex] = String(line.dropFirst(indentString.count))
            } else {
                // Remove leading whitespace up to indent width
                var removeCount = 0
                for char in line {
                    if char == " " || char == "\t" {
                        removeCount += 1
                        if removeCount >= indentString.count { break }
                    } else {
                        break
                    }
                }
                if removeCount > 0 {
                    lines[lineIndex] = String(line.dropFirst(removeCount))
                }
            }
        }
    }
    
    /// Number lines in column selection (insert sequential numbers)
    func numberColumn(in lines: inout [String], selection: ColumnSelection, startNumber: Int = 1, padding: Int = 0) {
        for (offset, lineIndex) in (selection.topLine...selection.bottomLine).enumerated() {
            guard lineIndex < lines.count else { continue }
            
            let number = startNumber + offset
            let numberStr: String
            if padding > 0 {
                numberStr = String(format: "%0\(padding)d", number)
            } else {
                numberStr = String(number)
            }
            
            var line = lines[lineIndex]
            let insertColumn = selection.leftColumn
            
            // Pad if necessary
            if line.count < insertColumn {
                line += String(repeating: " ", count: insertColumn - line.count)
            }
            
            let insertIdx = line.index(line.startIndex, offsetBy: insertColumn)
            line.insert(contentsOf: numberStr, at: insertIdx)
            lines[lineIndex] = line
        }
    }
}

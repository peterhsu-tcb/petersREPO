import Foundation

/// Represents the type of change in a diff
enum DiffChangeType: Equatable {
    case unchanged
    case added
    case removed
    case modified
}

/// Represents a character range with its change status for inline diff highlighting
struct CharacterDiff: Equatable {
    let range: Range<String.Index>
    let isChanged: Bool
    
    init(range: Range<String.Index>, isChanged: Bool) {
        self.range = range
        self.isChanged = isChanged
    }
}

/// Represents a single line in a diff result
struct DiffLine: Identifiable, Equatable {
    let id: UUID
    let lineNumber: Int?
    let content: String
    let changeType: DiffChangeType
    /// Character-level diffs for modified lines - shows which characters differ
    let characterDiffs: [CharacterDiff]
    
    init(lineNumber: Int?, content: String, changeType: DiffChangeType, characterDiffs: [CharacterDiff] = []) {
        self.id = UUID()
        self.lineNumber = lineNumber
        self.content = content
        self.changeType = changeType
        self.characterDiffs = characterDiffs
    }
}

/// Represents a chunk of changes in a diff
struct DiffChunk: Identifiable, Equatable {
    let id: UUID
    let leftStartLine: Int
    let leftLineCount: Int
    let rightStartLine: Int
    let rightLineCount: Int
    let leftLines: [DiffLine]
    let rightLines: [DiffLine]
    
    init(
        leftStartLine: Int,
        leftLineCount: Int,
        rightStartLine: Int,
        rightLineCount: Int,
        leftLines: [DiffLine],
        rightLines: [DiffLine]
    ) {
        self.id = UUID()
        self.leftStartLine = leftStartLine
        self.leftLineCount = leftLineCount
        self.rightStartLine = rightStartLine
        self.rightLineCount = rightLineCount
        self.leftLines = leftLines
        self.rightLines = rightLines
    }
}

/// Represents the result of comparing two files
struct DiffResult: Identifiable, Equatable {
    let id: UUID
    let leftFile: URL?
    let rightFile: URL?
    let chunks: [DiffChunk]
    let leftLines: [DiffLine]
    let rightLines: [DiffLine]
    let isIdentical: Bool
    let leftFileExists: Bool
    let rightFileExists: Bool
    
    init(
        leftFile: URL?,
        rightFile: URL?,
        chunks: [DiffChunk],
        leftLines: [DiffLine],
        rightLines: [DiffLine],
        isIdentical: Bool,
        leftFileExists: Bool = true,
        rightFileExists: Bool = true
    ) {
        self.id = UUID()
        self.leftFile = leftFile
        self.rightFile = rightFile
        self.chunks = chunks
        self.leftLines = leftLines
        self.rightLines = rightLines
        self.isIdentical = isIdentical
        self.leftFileExists = leftFileExists
        self.rightFileExists = rightFileExists
    }
    
    /// Returns statistics about the diff
    var statistics: DiffStatistics {
        var added = 0
        var removed = 0
        var modified = 0
        var unchanged = 0
        
        // Count from rightLines only to avoid double-counting
        // Added lines only appear in rightLines, removed only in leftLines
        for line in rightLines {
            switch line.changeType {
            case .added: added += 1
            case .removed: removed += 1
            case .modified: modified += 1
            case .unchanged: unchanged += 1
            }
        }
        
        // Count removed lines from leftLines (they don't appear in rightLines)
        for line in leftLines {
            if line.changeType == .removed {
                removed += 1
            }
        }
        
        return DiffStatistics(
            added: added,
            removed: removed,
            modified: modified,
            unchanged: unchanged
        )
    }
}

/// Statistics about a diff result
struct DiffStatistics: Equatable {
    let added: Int
    let removed: Int
    let modified: Int
    let unchanged: Int
    
    var totalChanges: Int {
        added + removed + modified
    }
    
    var summary: String {
        if totalChanges == 0 {
            return "Files are identical"
        }
        var parts: [String] = []
        if added > 0 { parts.append("+\(added)") }
        if removed > 0 { parts.append("-\(removed)") }
        if modified > 0 { parts.append("~\(modified)") }
        return parts.joined(separator: " ")
    }
}

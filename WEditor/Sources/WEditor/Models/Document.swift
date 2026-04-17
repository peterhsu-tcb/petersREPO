import Foundation

/// Represents an open document in the editor
class Document: ObservableObject, Identifiable {
    let id: UUID
    @Published var url: URL?
    @Published var content: String
    @Published var originalContent: String
    @Published var encoding: String.Encoding
    @Published var lineEnding: LineEnding
    @Published var isModified: Bool = false
    @Published var cursorPosition: CursorPosition = CursorPosition()
    @Published var selection: TextSelection?
    @Published var columnSelection: ColumnSelection?
    @Published var language: SyntaxLanguage
    @Published var undoStack: [EditAction] = []
    @Published var redoStack: [EditAction] = []
    
    /// Lines cache for efficient line-based operations
    @Published var lines: [String] = []
    
    var name: String {
        url?.lastPathComponent ?? "Untitled"
    }
    
    var displayName: String {
        let modified = isModified ? " •" : ""
        return name + modified
    }
    
    init(url: URL? = nil, content: String = "", encoding: String.Encoding = .utf8, language: SyntaxLanguage = .plainText) {
        self.id = UUID()
        self.url = url
        self.content = content
        self.originalContent = content
        self.encoding = encoding
        self.language = language
        self.lineEnding = Document.detectLineEnding(in: content)
        self.lines = content.components(separatedBy: "\n")
    }
    
    /// Update content and recalculate lines
    func updateContent(_ newContent: String) {
        let oldContent = content
        content = newContent
        lines = newContent.components(separatedBy: "\n")
        isModified = (content != originalContent)
        
        // Push undo action
        undoStack.append(EditAction(oldContent: oldContent, newContent: newContent, cursorPosition: cursorPosition))
        redoStack.removeAll()
    }
    
    /// Mark as saved
    func markSaved() {
        originalContent = content
        isModified = false
    }
    
    /// Undo last edit
    func undo() {
        guard let action = undoStack.popLast() else { return }
        content = action.oldContent
        lines = content.components(separatedBy: "\n")
        isModified = (content != originalContent)
        redoStack.append(action)
    }
    
    /// Redo last undone edit
    func redo() {
        guard let action = redoStack.popLast() else { return }
        content = action.newContent
        lines = content.components(separatedBy: "\n")
        isModified = (content != originalContent)
        undoStack.append(action)
    }
    
    /// Detect line ending style
    static func detectLineEnding(in text: String) -> LineEnding {
        if text.contains("\r\n") {
            return .crlf
        } else if text.contains("\r") {
            return .cr
        }
        return .lf
    }
    
    /// Get line at given index (0-based)
    func line(at index: Int) -> String? {
        guard index >= 0 && index < lines.count else { return nil }
        return lines[index]
    }
    
    /// Total line count
    var lineCount: Int {
        return lines.count
    }
    
    /// Insert text at cursor position
    func insertAtCursor(_ text: String) {
        let lineIndex = cursorPosition.line
        let colIndex = cursorPosition.column
        
        guard lineIndex < lines.count else { return }
        
        var line = lines[lineIndex]
        let insertIndex = line.index(line.startIndex, offsetBy: min(colIndex, line.count))
        line.insert(contentsOf: text, at: insertIndex)
        lines[lineIndex] = line
        
        let newContent = lines.joined(separator: "\n")
        updateContent(newContent)
        
        // Move cursor forward
        cursorPosition.column += text.count
    }
    
    /// Delete character before cursor (backspace)
    func deleteBeforeCursor() {
        let lineIndex = cursorPosition.line
        let colIndex = cursorPosition.column
        
        if colIndex > 0 {
            guard lineIndex < lines.count else { return }
            var line = lines[lineIndex]
            let deleteIndex = line.index(line.startIndex, offsetBy: colIndex - 1)
            line.remove(at: deleteIndex)
            lines[lineIndex] = line
            cursorPosition.column -= 1
        } else if lineIndex > 0 {
            // Merge with previous line
            let prevLine = lines[lineIndex - 1]
            let currentLine = lines[lineIndex]
            cursorPosition.column = prevLine.count
            lines[lineIndex - 1] = prevLine + currentLine
            lines.remove(at: lineIndex)
            cursorPosition.line -= 1
        }
        
        let newContent = lines.joined(separator: "\n")
        updateContent(newContent)
    }
    
    /// Insert new line at cursor
    func insertNewLine() {
        let lineIndex = cursorPosition.line
        let colIndex = cursorPosition.column
        
        guard lineIndex < lines.count else { return }
        
        let line = lines[lineIndex]
        let splitIndex = line.index(line.startIndex, offsetBy: min(colIndex, line.count))
        let before = String(line[line.startIndex..<splitIndex])
        let after = String(line[splitIndex..<line.endIndex])
        
        lines[lineIndex] = before
        lines.insert(after, at: lineIndex + 1)
        
        cursorPosition.line += 1
        cursorPosition.column = 0
        
        let newContent = lines.joined(separator: "\n")
        updateContent(newContent)
    }
}

/// Cursor position in the document
struct CursorPosition: Equatable {
    var line: Int = 0
    var column: Int = 0
}

/// Text selection (non-column)
struct TextSelection: Equatable {
    var startLine: Int
    var startColumn: Int
    var endLine: Int
    var endColumn: Int
    
    var isEmpty: Bool {
        return startLine == endLine && startColumn == endColumn
    }
}

/// Column (block) selection for column edit mode
struct ColumnSelection: Equatable {
    var startLine: Int
    var startColumn: Int
    var endLine: Int
    var endColumn: Int
    
    /// The rectangular region covered by this selection
    var topLine: Int { min(startLine, endLine) }
    var bottomLine: Int { max(startLine, endLine) }
    var leftColumn: Int { min(startColumn, endColumn) }
    var rightColumn: Int { max(startColumn, endColumn) }
    
    /// Number of lines in the selection
    var lineCount: Int { bottomLine - topLine + 1 }
    
    /// Width of the column selection
    var width: Int { rightColumn - leftColumn }
}

/// Line ending types
enum LineEnding: String, CaseIterable {
    case lf = "LF"
    case cr = "CR"
    case crlf = "CRLF"
    
    var character: String {
        switch self {
        case .lf: return "\n"
        case .cr: return "\r"
        case .crlf: return "\r\n"
        }
    }
}

/// An edit action for undo/redo
struct EditAction {
    let oldContent: String
    let newContent: String
    let cursorPosition: CursorPosition
}

import SwiftUI

/// Main application entry point
@main
struct WEditorApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settings = EditorSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(settings)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    appState.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("New Window") {
                    // Opens a new window
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Open...") {
                    appState.showOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                // Recent files submenu
                Menu("Open Recent") {
                    ForEach(settings.recentFiles, id: \.absoluteString) { url in
                        Button(url.lastPathComponent) {
                            appState.openFile(at: url)
                        }
                    }
                    
                    if !settings.recentFiles.isEmpty {
                        Divider()
                        Button("Clear Recent") {
                            settings.recentFiles.removeAll()
                        }
                    }
                }
                
                Divider()
                
                Button("Save") {
                    appState.saveActiveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.activeDocument == nil)
                
                Button("Save As...") {
                    appState.saveActiveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.activeDocument == nil)
                
                Button("Save All") {
                    appState.saveAllDocuments()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                
                Divider()
                
                Button("Close Tab") {
                    if let doc = appState.activeDocument {
                        appState.closeDocument(doc)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.activeDocument == nil)
            }
            
            // Edit menu enhancements
            CommandMenu("Selection") {
                Button("Select All") {
                    appState.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)
                
                Divider()
                
                Button("Toggle Column Edit Mode") {
                    appState.isColumnEditMode.toggle()
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Divider()
                
                Button("Select Line") {
                    appState.selectCurrentLine()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                
                Button("Select Word") {
                    appState.selectCurrentWord()
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Divider()
                
                Button("Duplicate Line") {
                    appState.duplicateCurrentLine()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Button("Delete Line") {
                    appState.deleteCurrentLine()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Button("Move Line Up") {
                    appState.moveLineUp()
                }
                .keyboardShortcut(.upArrow, modifiers: [.option])
                
                Button("Move Line Down") {
                    appState.moveLineDown()
                }
                .keyboardShortcut(.downArrow, modifiers: [.option])
            }
            
            // Search menu
            CommandMenu("Search") {
                Button("Find...") {
                    appState.showFindReplace = true
                    appState.showReplace = false
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Button("Find and Replace...") {
                    appState.showFindReplace = true
                    appState.showReplace = true
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                
                Divider()
                
                Button("Find Next") {
                    appState.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Button("Find Previous") {
                    appState.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Go to Line...") {
                    appState.showGoToLine = true
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
            }
            
            // View menu
            CommandMenu("Editor") {
                Button("Increase Font Size") {
                    settings.fontSize = min(settings.fontSize + 1, 32)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Decrease Font Size") {
                    settings.fontSize = max(settings.fontSize - 1, 8)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Reset Font Size") {
                    settings.fontSize = 14
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Toggle("Word Wrap", isOn: $settings.wordWrap)
                    .keyboardShortcut("z", modifiers: [.command, .option])
                
                Toggle("Show Line Numbers", isOn: $settings.showLineNumbers)
                
                Toggle("Show Mini Map", isOn: $settings.showMiniMap)
                
                Toggle("Show Whitespace", isOn: $settings.showWhitespace)
                
                Toggle("Highlight Current Line", isOn: $settings.highlightCurrentLine)
                
                Divider()
                
                // Language selection
                Menu("Syntax Language") {
                    ForEach(SyntaxLanguage.allCases) { lang in
                        Button(lang.rawValue) {
                            appState.activeDocument?.language = lang
                        }
                    }
                }
            }
            
            // Column edit menu
            CommandMenu("Column") {
                Button("Toggle Column Edit Mode") {
                    appState.isColumnEditMode.toggle()
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Divider()
                
                Button("Expand Column Selection Up") {
                    appState.expandColumnSelectionUp()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(!appState.isColumnEditMode)
                
                Button("Expand Column Selection Down") {
                    appState.expandColumnSelectionDown()
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!appState.isColumnEditMode)
                
                Button("Expand Column Selection Left") {
                    appState.expandColumnSelectionLeft()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(!appState.isColumnEditMode)
                
                Button("Expand Column Selection Right") {
                    appState.expandColumnSelectionRight()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(!appState.isColumnEditMode)
                
                Divider()
                
                Button("Insert Column Text...") {
                    appState.columnInsertText()
                }
                .disabled(!appState.isColumnEditMode || appState.activeDocument?.columnSelection == nil)
                
                Button("Delete Column Selection") {
                    appState.columnDeleteSelection()
                }
                .disabled(!appState.isColumnEditMode || appState.activeDocument?.columnSelection == nil)
                
                Divider()
                
                Button("Number Lines...") {
                    appState.columnNumberLines()
                }
                .disabled(!appState.isColumnEditMode || appState.activeDocument?.columnSelection == nil)
                
                Button("Fill with Character...") {
                    appState.columnFillCharacter()
                }
                .disabled(!appState.isColumnEditMode || appState.activeDocument?.columnSelection == nil)
            }
            
            // HTML editing menu
            CommandMenu("HTML") {
                Button("Source View") {
                    appState.activeDocument?.htmlEditMode = .source
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(appState.activeDocument?.isHTML != true)
                
                Button("Visual Editor") {
                    appState.activeDocument?.htmlEditMode = .visual
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(appState.activeDocument?.isHTML != true)
                
                Button("Split View") {
                    appState.activeDocument?.htmlEditMode = .split
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                .disabled(appState.activeDocument?.isHTML != true)
                
                Divider()
                
                Button("Toggle Visual/Source") {
                    appState.toggleHTMLEditMode()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(appState.activeDocument?.isHTML != true)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

/// Application state shared across views
class AppState: ObservableObject {
    @Published var documents: [Document] = []
    @Published var activeDocumentId: UUID?
    @Published var isColumnEditMode: Bool = false
    @Published var showFindReplace: Bool = false
    @Published var showReplace: Bool = false
    @Published var showGoToLine: Bool = false
    @Published var searchMatches: [SearchMatch] = []
    @Published var currentSearchMatch: SearchMatch?
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    
    private let fileService = FileService()
    private let columnEditService = ColumnEditService()
    private let searchService = SearchReplaceService()
    
    /// Currently active document
    var activeDocument: Document? {
        documents.first { $0.id == activeDocumentId }
    }
    
    // MARK: - Document Management
    
    /// Create a new empty document
    func newDocument() {
        let doc = Document()
        documents.append(doc)
        activeDocumentId = doc.id
    }
    
    /// Set active document
    func setActiveDocument(_ document: Document) {
        activeDocumentId = document.id
    }
    
    /// Open a file
    func openFile(at url: URL) {
        // Check if already open
        if let existing = documents.first(where: { $0.url == url }) {
            activeDocumentId = existing.id
            return
        }
        
        do {
            let (content, encoding) = try fileService.readFile(at: url)
            let language = SyntaxLanguage.detect(from: url)
            let doc = Document(url: url, content: content, encoding: encoding, language: language)
            documents.append(doc)
            activeDocumentId = doc.id
        } catch {
            errorMessage = "Failed to open file: \(error.localizedDescription)"
        }
    }
    
    /// Show open panel
    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                openFile(at: url)
            }
        }
    }
    
    /// Close a document
    func closeDocument(_ document: Document) {
        documents.removeAll { $0.id == document.id }
        
        if activeDocumentId == document.id {
            activeDocumentId = documents.last?.id
        }
    }
    
    /// Save active document
    func saveActiveDocument() {
        guard let doc = activeDocument else { return }
        
        if let url = doc.url {
            do {
                try fileService.writeFile(content: doc.content, to: url, encoding: doc.encoding)
                doc.markSaved()
                statusMessage = "Saved: \(url.lastPathComponent)"
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        } else {
            saveActiveDocumentAs()
        }
    }
    
    /// Save active document with a new name
    func saveActiveDocumentAs() {
        guard let doc = activeDocument else { return }
        
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.name
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try fileService.writeFile(content: doc.content, to: url, encoding: doc.encoding)
                doc.url = url
                doc.language = SyntaxLanguage.detect(from: url)
                doc.markSaved()
                statusMessage = "Saved: \(url.lastPathComponent)"
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    
    /// Save all documents
    func saveAllDocuments() {
        for doc in documents where doc.isModified {
            if let url = doc.url {
                do {
                    try fileService.writeFile(content: doc.content, to: url, encoding: doc.encoding)
                    doc.markSaved()
                } catch {
                    errorMessage = "Failed to save \(doc.name): \(error.localizedDescription)"
                }
            }
        }
        statusMessage = "All documents saved"
    }
    
    // MARK: - Selection Operations
    
    /// Select all text
    func selectAll() {
        guard let doc = activeDocument else { return }
        doc.selection = TextSelection(
            startLine: 0,
            startColumn: 0,
            endLine: doc.lineCount - 1,
            endColumn: doc.lines.last?.count ?? 0
        )
    }
    
    /// Select current line
    func selectCurrentLine() {
        guard let doc = activeDocument else { return }
        let line = doc.cursorPosition.line
        doc.selection = TextSelection(
            startLine: line,
            startColumn: 0,
            endLine: line,
            endColumn: doc.lines[safe: line]?.count ?? 0
        )
    }
    
    /// Select current word
    func selectCurrentWord() {
        guard let doc = activeDocument,
              let line = doc.line(at: doc.cursorPosition.line) else { return }
        
        let col = doc.cursorPosition.column
        var start = col
        var end = col
        
        // Find word boundaries
        while start > 0 && line[line.index(line.startIndex, offsetBy: start - 1)].isLetter {
            start -= 1
        }
        while end < line.count && line[line.index(line.startIndex, offsetBy: end)].isLetter {
            end += 1
        }
        
        doc.selection = TextSelection(
            startLine: doc.cursorPosition.line,
            startColumn: start,
            endLine: doc.cursorPosition.line,
            endColumn: end
        )
    }
    
    // MARK: - Line Operations
    
    /// Duplicate current line
    func duplicateCurrentLine() {
        guard let doc = activeDocument else { return }
        let lineIndex = doc.cursorPosition.line
        guard lineIndex < doc.lines.count else { return }
        
        let line = doc.lines[lineIndex]
        doc.lines.insert(line, at: lineIndex + 1)
        doc.updateContent(doc.lines.joined(separator: "\n"))
    }
    
    /// Delete current line
    func deleteCurrentLine() {
        guard let doc = activeDocument else { return }
        let lineIndex = doc.cursorPosition.line
        guard lineIndex < doc.lines.count else { return }
        
        doc.lines.remove(at: lineIndex)
        if doc.lines.isEmpty {
            doc.lines = [""]
        }
        doc.cursorPosition.line = min(lineIndex, doc.lines.count - 1)
        doc.cursorPosition.column = 0
        doc.updateContent(doc.lines.joined(separator: "\n"))
    }
    
    /// Move current line up
    func moveLineUp() {
        guard let doc = activeDocument else { return }
        let lineIndex = doc.cursorPosition.line
        guard lineIndex > 0 && lineIndex < doc.lines.count else { return }
        
        doc.lines.swapAt(lineIndex, lineIndex - 1)
        doc.cursorPosition.line -= 1
        doc.updateContent(doc.lines.joined(separator: "\n"))
    }
    
    /// Move current line down
    func moveLineDown() {
        guard let doc = activeDocument else { return }
        let lineIndex = doc.cursorPosition.line
        guard lineIndex < doc.lines.count - 1 else { return }
        
        doc.lines.swapAt(lineIndex, lineIndex + 1)
        doc.cursorPosition.line += 1
        doc.updateContent(doc.lines.joined(separator: "\n"))
    }
    
    // MARK: - Search Operations
    
    func findNext() {
        guard let doc = activeDocument, let match = currentSearchMatch else { return }
        if let next = searchService.findNext(
            in: doc.lines,
            searchText: match.matchText,
            fromLine: doc.cursorPosition.line,
            fromColumn: doc.cursorPosition.column,
            options: SearchOptions()
        ) {
            doc.cursorPosition = CursorPosition(line: next.line, column: next.column)
            currentSearchMatch = next
        }
    }
    
    func findPrevious() {
        guard let doc = activeDocument, let match = currentSearchMatch else { return }
        if let prev = searchService.findPrevious(
            in: doc.lines,
            searchText: match.matchText,
            fromLine: doc.cursorPosition.line,
            fromColumn: doc.cursorPosition.column,
            options: SearchOptions()
        ) {
            doc.cursorPosition = CursorPosition(line: prev.line, column: prev.column)
            currentSearchMatch = prev
        }
    }
    
    // MARK: - HTML Edit Mode
    
    /// Toggle between source and visual HTML editing modes
    func toggleHTMLEditMode() {
        guard let doc = activeDocument, doc.isHTML else { return }
        
        switch doc.htmlEditMode {
        case .source:
            doc.htmlEditMode = .visual
        case .visual:
            doc.htmlEditMode = .source
        case .split:
            doc.htmlEditMode = .source
        }
    }
    
    // MARK: - Column Edit Operations
    
    /// Insert text at column selection
    func columnInsertText() {
        guard let doc = activeDocument,
              let selection = doc.columnSelection else { return }
        
        // For now, insert empty string - in a full app this would show a dialog
        var lines = doc.lines
        columnEditService.insertColumn(in: &lines, text: " ", selection: selection)
        doc.updateContent(lines.joined(separator: "\n"))
    }
    
    /// Delete column selection
    func columnDeleteSelection() {
        guard let doc = activeDocument,
              let selection = doc.columnSelection else { return }
        
        var lines = doc.lines
        columnEditService.deleteColumn(in: &lines, selection: selection)
        doc.updateContent(lines.joined(separator: "\n"))
        doc.columnSelection = nil
    }
    
    /// Number lines in column selection
    func columnNumberLines() {
        guard let doc = activeDocument,
              let selection = doc.columnSelection else { return }
        
        var lines = doc.lines
        columnEditService.numberColumn(in: &lines, selection: selection)
        doc.updateContent(lines.joined(separator: "\n"))
    }
    
    /// Fill column selection with character
    func columnFillCharacter() {
        guard let doc = activeDocument,
              let selection = doc.columnSelection else { return }
        
        var lines = doc.lines
        columnEditService.fillColumn(in: &lines, selection: selection, character: " ")
        doc.updateContent(lines.joined(separator: "\n"))
    }
    
    /// Replace text within column selection
    func columnReplaceText(searchText: String, replacement: String, options: SearchOptions) {
        guard let doc = activeDocument,
              let colSel = doc.columnSelection else { return }
        
        var lines = doc.lines
        // Extract column text, perform search/replace within it, then put it back
        let columnTexts = columnEditService.extractColumnText(from: lines, selection: colSel)
        var modified = false
        
        for (offset, colText) in columnTexts.enumerated() {
            let lineIndex = colSel.topLine + offset
            guard lineIndex < lines.count else { continue }
            
            let replacedText: String
            if options.caseSensitive {
                replacedText = colText.replacingOccurrences(of: searchText, with: replacement)
            } else {
                replacedText = colText.replacingOccurrences(of: searchText, with: replacement, options: .caseInsensitive)
            }
            
            if replacedText != colText {
                modified = true
                // Reconstruct the line with the replaced column text
                let line = lines[lineIndex]
                let lineLength = line.count
                let leftCol = colSel.leftColumn
                let rightCol = min(colSel.rightColumn, lineLength)
                
                if leftCol < lineLength {
                    let before = String(line.prefix(leftCol))
                    let after = rightCol < lineLength ? String(line.suffix(lineLength - rightCol)) : ""
                    lines[lineIndex] = before + replacedText + after
                }
            }
        }
        
        if modified {
            doc.updateContent(lines.joined(separator: "\n"))
        }
    }
    
    // MARK: - Column Selection Navigation
    
    /// Initialize column selection at cursor if not already present
    private func ensureColumnSelection() -> ColumnSelection? {
        guard let doc = activeDocument else { return nil }
        
        if let existing = doc.columnSelection {
            return existing
        }
        
        // Create a new column selection starting at cursor position
        let sel = ColumnSelection(
            startLine: doc.cursorPosition.line,
            startColumn: doc.cursorPosition.column,
            endLine: doc.cursorPosition.line,
            endColumn: doc.cursorPosition.column
        )
        doc.columnSelection = sel
        return sel
    }
    
    /// Expand column selection upward by one line
    func expandColumnSelectionUp() {
        guard let doc = activeDocument,
              var sel = ensureColumnSelection() else { return }
        
        if sel.endLine > 0 {
            sel.endLine -= 1
            doc.columnSelection = sel
            doc.cursorPosition.line = sel.endLine
        }
    }
    
    /// Expand column selection downward by one line
    func expandColumnSelectionDown() {
        guard let doc = activeDocument,
              var sel = ensureColumnSelection() else { return }
        
        if sel.endLine < doc.lineCount - 1 {
            sel.endLine += 1
            doc.columnSelection = sel
            doc.cursorPosition.line = sel.endLine
        }
    }
    
    /// Expand column selection left by one column
    func expandColumnSelectionLeft() {
        guard let doc = activeDocument,
              var sel = ensureColumnSelection() else { return }
        
        if sel.endColumn > 0 {
            sel.endColumn -= 1
            doc.columnSelection = sel
            doc.cursorPosition.column = sel.endColumn
        }
    }
    
    /// Expand column selection right by one column
    func expandColumnSelectionRight() {
        guard let doc = activeDocument,
              var sel = ensureColumnSelection() else { return }
        
        sel.endColumn += 1
        doc.columnSelection = sel
        doc.cursorPosition.column = sel.endColumn
    }
    
    /// Insert typed text at column selection (for each line in the selection)
    func columnTypeText(_ text: String) {
        guard let doc = activeDocument,
              let selection = doc.columnSelection else { return }
        
        var lines = doc.lines
        columnEditService.insertColumn(in: &lines, text: text, selection: selection)
        doc.updateContent(lines.joined(separator: "\n"))
        
        // Move the column selection right by the inserted text length
        doc.columnSelection = ColumnSelection(
            startLine: selection.startLine,
            startColumn: selection.startColumn + text.count,
            endLine: selection.endLine,
            endColumn: selection.endColumn + text.count
        )
    }
    
    /// Delete one character before the column selection (backspace in column mode)
    func columnBackspace() {
        guard let doc = activeDocument,
              let selection = doc.columnSelection else { return }
        
        if selection.width > 0 {
            // Delete the selected column content
            columnDeleteSelection()
        } else if selection.leftColumn > 0 {
            // Delete one character before the cursor column on each line
            let deleteSel = ColumnSelection(
                startLine: selection.startLine,
                startColumn: selection.startColumn - 1,
                endLine: selection.endLine,
                endColumn: selection.endColumn
            )
            var lines = doc.lines
            columnEditService.deleteColumn(in: &lines, selection: deleteSel)
            doc.updateContent(lines.joined(separator: "\n"))
            
            // Move selection left
            doc.columnSelection = ColumnSelection(
                startLine: selection.startLine,
                startColumn: selection.startColumn - 1,
                endLine: selection.endLine,
                endColumn: selection.endColumn - 1
            )
        }
    }
}

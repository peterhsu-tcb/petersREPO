import XCTest
@testable import WEditor

final class WEditorTests: XCTestCase {
    
    // MARK: - Document Tests
    
    func testDocumentInitialization() {
        let doc = Document(content: "Hello\nWorld")
        
        XCTAssertEqual(doc.content, "Hello\nWorld")
        XCTAssertEqual(doc.lineCount, 2)
        XCTAssertEqual(doc.lines, ["Hello", "World"])
        XCTAssertFalse(doc.isModified)
        XCTAssertNil(doc.url)
        XCTAssertEqual(doc.name, "Untitled")
        XCTAssertEqual(doc.language, .plainText)
    }
    
    func testDocumentUpdateContent() {
        let doc = Document(content: "Hello")
        
        doc.updateContent("Hello\nWorld")
        
        XCTAssertEqual(doc.lineCount, 2)
        XCTAssertTrue(doc.isModified)
        XCTAssertEqual(doc.lines[0], "Hello")
        XCTAssertEqual(doc.lines[1], "World")
    }
    
    func testDocumentMarkSaved() {
        let doc = Document(content: "Hello")
        doc.updateContent("Hello World")
        
        XCTAssertTrue(doc.isModified)
        
        doc.markSaved()
        
        XCTAssertFalse(doc.isModified)
    }
    
    func testDocumentUndo() {
        let doc = Document(content: "Hello")
        
        doc.updateContent("Hello World")
        XCTAssertEqual(doc.content, "Hello World")
        
        doc.undo()
        XCTAssertEqual(doc.content, "Hello")
        XCTAssertFalse(doc.isModified)
    }
    
    func testDocumentRedo() {
        let doc = Document(content: "Hello")
        
        doc.updateContent("Hello World")
        doc.undo()
        XCTAssertEqual(doc.content, "Hello")
        
        doc.redo()
        XCTAssertEqual(doc.content, "Hello World")
    }
    
    func testDocumentLineAccess() {
        let doc = Document(content: "Line 1\nLine 2\nLine 3")
        
        XCTAssertEqual(doc.line(at: 0), "Line 1")
        XCTAssertEqual(doc.line(at: 1), "Line 2")
        XCTAssertEqual(doc.line(at: 2), "Line 3")
        XCTAssertNil(doc.line(at: 3))
        XCTAssertNil(doc.line(at: -1))
    }
    
    func testDocumentDisplayName() {
        let doc = Document(content: "test")
        XCTAssertEqual(doc.displayName, "Untitled")
        
        doc.updateContent("changed")
        XCTAssertEqual(doc.displayName, "Untitled •")
    }
    
    func testDocumentLineEndingDetection() {
        XCTAssertEqual(Document.detectLineEnding(in: "Hello\nWorld"), .lf)
        XCTAssertEqual(Document.detectLineEnding(in: "Hello\r\nWorld"), .crlf)
        XCTAssertEqual(Document.detectLineEnding(in: "Hello\rWorld"), .cr)
        XCTAssertEqual(Document.detectLineEnding(in: "Hello World"), .lf) // default
    }
    
    func testDocumentInsertAtCursor() {
        let doc = Document(content: "Hello World")
        doc.cursorPosition = CursorPosition(line: 0, column: 5)
        
        doc.insertAtCursor(",")
        
        XCTAssertEqual(doc.lines[0], "Hello, World")
        XCTAssertEqual(doc.cursorPosition.column, 6)
    }
    
    func testDocumentDeleteBeforeCursor() {
        let doc = Document(content: "Hello World")
        doc.cursorPosition = CursorPosition(line: 0, column: 5)
        
        doc.deleteBeforeCursor()
        
        XCTAssertEqual(doc.lines[0], "Hell World")
        XCTAssertEqual(doc.cursorPosition.column, 4)
    }
    
    func testDocumentDeleteBeforeCursorMergeLines() {
        let doc = Document(content: "Hello\nWorld")
        doc.cursorPosition = CursorPosition(line: 1, column: 0)
        
        doc.deleteBeforeCursor()
        
        XCTAssertEqual(doc.lineCount, 1)
        XCTAssertEqual(doc.lines[0], "HelloWorld")
        XCTAssertEqual(doc.cursorPosition.line, 0)
        XCTAssertEqual(doc.cursorPosition.column, 5)
    }
    
    func testDocumentInsertNewLine() {
        let doc = Document(content: "HelloWorld")
        doc.cursorPosition = CursorPosition(line: 0, column: 5)
        
        doc.insertNewLine()
        
        XCTAssertEqual(doc.lineCount, 2)
        XCTAssertEqual(doc.lines[0], "Hello")
        XCTAssertEqual(doc.lines[1], "World")
        XCTAssertEqual(doc.cursorPosition.line, 1)
        XCTAssertEqual(doc.cursorPosition.column, 0)
    }
    
    // MARK: - CursorPosition Tests
    
    func testCursorPositionEquality() {
        let pos1 = CursorPosition(line: 1, column: 5)
        let pos2 = CursorPosition(line: 1, column: 5)
        let pos3 = CursorPosition(line: 2, column: 5)
        
        XCTAssertEqual(pos1, pos2)
        XCTAssertNotEqual(pos1, pos3)
    }
    
    // MARK: - TextSelection Tests
    
    func testTextSelectionEmpty() {
        let sel = TextSelection(startLine: 1, startColumn: 5, endLine: 1, endColumn: 5)
        XCTAssertTrue(sel.isEmpty)
        
        let sel2 = TextSelection(startLine: 1, startColumn: 5, endLine: 1, endColumn: 10)
        XCTAssertFalse(sel2.isEmpty)
    }
    
    // MARK: - ColumnSelection Tests
    
    func testColumnSelectionProperties() {
        let sel = ColumnSelection(startLine: 2, startColumn: 10, endLine: 5, endColumn: 20)
        
        XCTAssertEqual(sel.topLine, 2)
        XCTAssertEqual(sel.bottomLine, 5)
        XCTAssertEqual(sel.leftColumn, 10)
        XCTAssertEqual(sel.rightColumn, 20)
        XCTAssertEqual(sel.lineCount, 4)
        XCTAssertEqual(sel.width, 10)
    }
    
    func testColumnSelectionReversed() {
        // Selection made from bottom-right to top-left
        let sel = ColumnSelection(startLine: 5, startColumn: 20, endLine: 2, endColumn: 10)
        
        XCTAssertEqual(sel.topLine, 2)
        XCTAssertEqual(sel.bottomLine, 5)
        XCTAssertEqual(sel.leftColumn, 10)
        XCTAssertEqual(sel.rightColumn, 20)
    }
    
    // MARK: - LineEnding Tests
    
    func testLineEndingCharacters() {
        XCTAssertEqual(LineEnding.lf.character, "\n")
        XCTAssertEqual(LineEnding.cr.character, "\r")
        XCTAssertEqual(LineEnding.crlf.character, "\r\n")
    }
    
    // MARK: - SyntaxLanguage Tests
    
    func testLanguageDetectionFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.swift")), .swift)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.py")), .python)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.js")), .javascript)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.ts")), .typescript)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.java")), .java)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.cs")), .cSharp)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.cpp")), .cpp)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.c")), .c)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.rb")), .ruby)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.go")), .go)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.rs")), .rust)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.php")), .php)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.html")), .html)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.css")), .css)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.json")), .json)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.xml")), .xml)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.yml")), .yaml)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.md")), .markdown)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.sql")), .sql)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.sh")), .shell)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.pl")), .perl)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.lua")), .lua)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.r")), .r)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.kt")), .kotlin)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.scala")), .scala)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.dart")), .dart)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.ex")), .elixir)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.hs")), .haskell)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.toml")), .toml)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.ini")), .ini)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.txt")), .plainText)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.unknown")), .plainText)
    }
    
    func testLanguageDetectionFromSpecialFilenames() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/Dockerfile")), .dockerfile)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/Makefile")), .makefile)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/Gemfile")), .ruby)
    }
    
    // MARK: - SyntaxDefinition Tests
    
    func testSyntaxDefinitionExists() {
        for language in SyntaxLanguage.allCases {
            let definition = SyntaxDefinition.definition(for: language)
            XCTAssertEqual(definition.language, language)
        }
    }
    
    func testPlainTextDefinitionHasNoRules() {
        let definition = SyntaxDefinition.definition(for: .plainText)
        XCTAssertTrue(definition.rules.isEmpty)
    }
    
    func testSwiftDefinitionHasRules() {
        let definition = SyntaxDefinition.definition(for: .swift)
        XCTAssertFalse(definition.rules.isEmpty)
        XCTAssertEqual(definition.singleLineComment, "//")
        XCTAssertEqual(definition.multiLineCommentStart, "/*")
        XCTAssertEqual(definition.multiLineCommentEnd, "*/")
    }
    
    // MARK: - EditorTheme Tests
    
    func testThemeColorForTokenType() {
        let theme = EditorTheme.defaultDark
        
        let keywordColor = theme.color(for: .keyword)
        let stringColor = theme.color(for: .string)
        let plainColor = theme.color(for: .plain)
        
        // Colors should be defined (not nil/default)
        XCTAssertNotEqual(keywordColor, Color.clear)
        XCTAssertNotEqual(stringColor, Color.clear)
        XCTAssertNotEqual(plainColor, Color.clear)
    }
    
    func testAllThemesExist() {
        XCTAssertGreaterThanOrEqual(EditorTheme.allThemes.count, 4)
        
        // Verify unique IDs
        let ids = EditorTheme.allThemes.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }
    
    func testThemeDarkLightVariant() {
        XCTAssertTrue(EditorTheme.defaultDark.isDark)
        XCTAssertFalse(EditorTheme.defaultLight.isDark)
        XCTAssertTrue(EditorTheme.monokai.isDark)
        XCTAssertTrue(EditorTheme.solarizedDark.isDark)
    }
    
    // MARK: - EditorSettings Tests
    
    func testEditorSettingsDefaults() {
        let settings = EditorSettings()
        
        XCTAssertEqual(settings.fontSize, 14)
        XCTAssertEqual(settings.fontName, "Menlo")
        XCTAssertEqual(settings.tabWidth, 4)
        XCTAssertTrue(settings.useSpacesForTabs)
        XCTAssertTrue(settings.showLineNumbers)
        XCTAssertTrue(settings.showMiniMap)
        XCTAssertFalse(settings.wordWrap)
        XCTAssertTrue(settings.highlightCurrentLine)
    }
    
    func testEditorSettingsTabString() {
        let settings = EditorSettings()
        
        settings.useSpacesForTabs = true
        settings.tabWidth = 4
        XCTAssertEqual(settings.tabString, "    ")
        
        settings.tabWidth = 2
        XCTAssertEqual(settings.tabString, "  ")
        
        settings.useSpacesForTabs = false
        XCTAssertEqual(settings.tabString, "\t")
    }
    
    func testEditorSettingsRecentFiles() {
        let settings = EditorSettings()
        settings.maxRecentFiles = 3
        
        let url1 = URL(fileURLWithPath: "/test/file1.txt")
        let url2 = URL(fileURLWithPath: "/test/file2.txt")
        let url3 = URL(fileURLWithPath: "/test/file3.txt")
        let url4 = URL(fileURLWithPath: "/test/file4.txt")
        
        settings.addRecentFile(url1)
        settings.addRecentFile(url2)
        settings.addRecentFile(url3)
        
        XCTAssertEqual(settings.recentFiles.count, 3)
        XCTAssertEqual(settings.recentFiles[0], url3) // Most recent first
        
        settings.addRecentFile(url4)
        XCTAssertEqual(settings.recentFiles.count, 3) // Max is 3
        XCTAssertEqual(settings.recentFiles[0], url4)
        XCTAssertFalse(settings.recentFiles.contains(url1)) // Oldest removed
    }
    
    // MARK: - SyntaxHighlightingService Tests
    
    func testHighlightSwiftKeyword() {
        let service = SyntaxHighlightingService()
        let line = "func hello() {"
        
        let result = service.highlightLine(line, lineIndex: 0, language: .swift)
        
        XCTAssertEqual(result.lineIndex, 0)
        XCTAssertEqual(result.text, line)
        XCTAssertFalse(result.tokens.isEmpty)
        
        // "func" should be highlighted as keyword
        let funcToken = result.tokens.first { $0.text == "func" }
        XCTAssertNotNil(funcToken)
        XCTAssertEqual(funcToken?.tokenType, .keyword)
    }
    
    func testHighlightSwiftString() {
        let service = SyntaxHighlightingService()
        let line = "let name = \"Hello World\""
        
        let result = service.highlightLine(line, lineIndex: 0, language: .swift)
        
        let stringToken = result.tokens.first { $0.tokenType == .string }
        XCTAssertNotNil(stringToken)
        XCTAssertTrue(stringToken?.text.contains("Hello World") ?? false)
    }
    
    func testHighlightSwiftComment() {
        let service = SyntaxHighlightingService()
        let line = "// This is a comment"
        
        let result = service.highlightLine(line, lineIndex: 0, language: .swift)
        
        let commentToken = result.tokens.first { $0.tokenType == .comment }
        XCTAssertNotNil(commentToken)
    }
    
    func testHighlightSwiftNumber() {
        let service = SyntaxHighlightingService()
        let line = "let x = 42"
        
        let result = service.highlightLine(line, lineIndex: 0, language: .swift)
        
        let numberToken = result.tokens.first { $0.tokenType == .number }
        XCTAssertNotNil(numberToken)
        XCTAssertEqual(numberToken?.text, "42")
    }
    
    func testHighlightPythonKeyword() {
        let service = SyntaxHighlightingService()
        let line = "def hello():"
        
        let result = service.highlightLine(line, lineIndex: 0, language: .python)
        
        let defToken = result.tokens.first { $0.text == "def" }
        XCTAssertNotNil(defToken)
        XCTAssertEqual(defToken?.tokenType, .keyword)
    }
    
    func testHighlightPlainText() {
        let service = SyntaxHighlightingService()
        let line = "Just plain text"
        
        let result = service.highlightLine(line, lineIndex: 0, language: .plainText)
        
        XCTAssertTrue(result.tokens.isEmpty)
    }
    
    func testHighlightMultipleLines() {
        let service = SyntaxHighlightingService()
        let lines = ["func hello() {", "    print(\"world\")", "}"]
        
        let results = service.highlightLines(lines, language: .swift)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].lineIndex, 0)
        XCTAssertEqual(results[1].lineIndex, 1)
        XCTAssertEqual(results[2].lineIndex, 2)
    }
    
    func testHighlightRange() {
        let service = SyntaxHighlightingService()
        let lines = ["line 0", "func test() {", "    let x = 5", "}", "line 4"]
        
        let results = service.highlightRange(lines: lines, startLine: 1, endLine: 3, language: .swift)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].lineIndex, 1)
        XCTAssertEqual(results[2].lineIndex, 3)
    }
    
    // MARK: - SearchReplaceService Tests
    
    func testFindAll() {
        let service = SearchReplaceService()
        let lines = ["Hello World", "Hello Swift", "Goodbye World"]
        
        let matches = service.findAll(in: lines, searchText: "Hello", options: SearchOptions())
        
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].line, 0)
        XCTAssertEqual(matches[0].column, 0)
        XCTAssertEqual(matches[1].line, 1)
    }
    
    func testFindAllCaseInsensitive() {
        let service = SearchReplaceService()
        let lines = ["Hello World", "hello swift", "HELLO THERE"]
        
        let options = SearchOptions(caseSensitive: false)
        let matches = service.findAll(in: lines, searchText: "hello", options: options)
        
        XCTAssertEqual(matches.count, 3)
    }
    
    func testFindAllCaseSensitive() {
        let service = SearchReplaceService()
        let lines = ["Hello World", "hello swift", "HELLO THERE"]
        
        let options = SearchOptions(caseSensitive: true)
        let matches = service.findAll(in: lines, searchText: "Hello", options: options)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].line, 0)
    }
    
    func testFindAllWholeWord() {
        let service = SearchReplaceService()
        let lines = ["Hello World", "HelloWorld", "Say Hello there"]
        
        let options = SearchOptions(wholeWord: true)
        let matches = service.findAll(in: lines, searchText: "Hello", options: options)
        
        XCTAssertEqual(matches.count, 2) // "Hello" in lines 0 and 2
    }
    
    func testFindAllRegex() {
        let service = SearchReplaceService()
        let lines = ["foo123", "bar456", "baz789"]
        
        let options = SearchOptions(useRegex: true)
        let matches = service.findAll(in: lines, searchText: "\\d+", options: options)
        
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].matchText, "123")
        XCTAssertEqual(matches[1].matchText, "456")
        XCTAssertEqual(matches[2].matchText, "789")
    }
    
    func testFindNext() {
        let service = SearchReplaceService()
        let lines = ["A B A B", "A B A B"]
        
        let match = service.findNext(in: lines, searchText: "A", fromLine: 0, fromColumn: 0, options: SearchOptions())
        
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.line, 0)
        XCTAssertEqual(match?.column, 4)
    }
    
    func testFindNextWrapAround() {
        let service = SearchReplaceService()
        let lines = ["A B C", "D E F"]
        
        let match = service.findNext(in: lines, searchText: "A", fromLine: 1, fromColumn: 0, options: SearchOptions())
        
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.line, 0) // Wrapped to beginning
    }
    
    func testFindPrevious() {
        let service = SearchReplaceService()
        let lines = ["A B A B", "C D C D"]
        
        let match = service.findPrevious(in: lines, searchText: "A", fromLine: 1, fromColumn: 0, options: SearchOptions())
        
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.line, 0)
    }
    
    func testFindAllEmpty() {
        let service = SearchReplaceService()
        let lines = ["Hello World"]
        
        let matches = service.findAll(in: lines, searchText: "", options: SearchOptions())
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testReplaceInLine() {
        let service = SearchReplaceService()
        var lines = ["Hello World"]
        let match = SearchMatch(line: 0, column: 6, length: 5, matchText: "World")
        
        service.replace(in: &lines, match: match, replacement: "Swift")
        
        XCTAssertEqual(lines[0], "Hello Swift")
    }
    
    func testReplaceAll() {
        let service = SearchReplaceService()
        var lines = ["Hello World", "Hello Swift"]
        
        let count = service.replaceAll(in: &lines, searchText: "Hello", replacement: "Hi", options: SearchOptions())
        
        XCTAssertEqual(count, 2)
        XCTAssertEqual(lines[0], "Hi World")
        XCTAssertEqual(lines[1], "Hi Swift")
    }
    
    // MARK: - ColumnEditService Tests
    
    func testExtractColumnText() {
        let service = ColumnEditService()
        let lines = ["Hello World", "Swift Code!", "Test Lines!"]
        let selection = ColumnSelection(startLine: 0, startColumn: 6, endLine: 2, endColumn: 11)
        
        let result = service.extractColumnText(from: lines, selection: selection)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "World")
        XCTAssertEqual(result[1], "Code!")
        XCTAssertEqual(result[2], "Lines")
    }
    
    func testInsertColumn() {
        let service = ColumnEditService()
        var lines = ["Hello", "World", "Swift"]
        let selection = ColumnSelection(startLine: 0, startColumn: 0, endLine: 2, endColumn: 0)
        
        service.insertColumn(in: &lines, text: ">> ", selection: selection)
        
        XCTAssertEqual(lines[0], ">> Hello")
        XCTAssertEqual(lines[1], ">> World")
        XCTAssertEqual(lines[2], ">> Swift")
    }
    
    func testDeleteColumn() {
        let service = ColumnEditService()
        var lines = ["Hello World", "Swift Code!", "Test Lines!"]
        let selection = ColumnSelection(startLine: 0, startColumn: 5, endLine: 2, endColumn: 11)
        
        service.deleteColumn(in: &lines, selection: selection)
        
        XCTAssertEqual(lines[0], "Hello")
        XCTAssertEqual(lines[1], "Swift")
        XCTAssertEqual(lines[2], "Test ")
    }
    
    func testPasteColumn() {
        let service = ColumnEditService()
        var lines = ["AAA", "BBB", "CCC"]
        let pasteLines = ["11", "22", "33"]
        
        service.pasteColumn(in: &lines, pasteLines: pasteLines, startLine: 0, startColumn: 1)
        
        XCTAssertEqual(lines[0], "A11AA")
        XCTAssertEqual(lines[1], "B22BB")
        XCTAssertEqual(lines[2], "C33CC")
    }
    
    func testInsertColumnWithPadding() {
        let service = ColumnEditService()
        var lines = ["Hi", "Hey", "Ho"]
        let selection = ColumnSelection(startLine: 0, startColumn: 5, endLine: 2, endColumn: 5)
        
        service.insertColumn(in: &lines, text: "X", selection: selection)
        
        XCTAssertEqual(lines[0], "Hi   X")
        XCTAssertEqual(lines[1], "Hey  X")
        XCTAssertEqual(lines[2], "Ho   X")
    }
    
    func testFillColumn() {
        let service = ColumnEditService()
        var lines = ["Hello World", "Swift Code!", "Test Lines!"]
        let selection = ColumnSelection(startLine: 0, startColumn: 5, endLine: 2, endColumn: 11)
        
        service.fillColumn(in: &lines, selection: selection, character: "*")
        
        XCTAssertTrue(lines[0].contains("******"))
        XCTAssertTrue(lines[1].contains("******"))
        XCTAssertTrue(lines[2].contains("******"))
    }
    
    func testNumberColumn() {
        let service = ColumnEditService()
        var lines = ["AAA", "BBB", "CCC", "DDD"]
        let selection = ColumnSelection(startLine: 0, startColumn: 0, endLine: 3, endColumn: 0)
        
        service.numberColumn(in: &lines, selection: selection, startNumber: 1, padding: 2)
        
        XCTAssertEqual(lines[0], "01AAA")
        XCTAssertEqual(lines[1], "02BBB")
        XCTAssertEqual(lines[2], "03CCC")
        XCTAssertEqual(lines[3], "04DDD")
    }
    
    func testIndentColumn() {
        let service = ColumnEditService()
        var lines = ["Hello", "World", "Swift"]
        let selection = ColumnSelection(startLine: 0, startColumn: 0, endLine: 2, endColumn: 0)
        
        service.indentColumn(in: &lines, selection: selection, indentString: "    ")
        
        XCTAssertEqual(lines[0], "    Hello")
        XCTAssertEqual(lines[1], "    World")
        XCTAssertEqual(lines[2], "    Swift")
    }
    
    func testUnindentColumn() {
        let service = ColumnEditService()
        var lines = ["    Hello", "    World", "    Swift"]
        let selection = ColumnSelection(startLine: 0, startColumn: 0, endLine: 2, endColumn: 4)
        
        service.unindentColumn(in: &lines, selection: selection, indentString: "    ")
        
        XCTAssertEqual(lines[0], "Hello")
        XCTAssertEqual(lines[1], "World")
        XCTAssertEqual(lines[2], "Swift")
    }
    
    // MARK: - FileService Tests
    
    func testFileServiceReadWrite() throws {
        let service = FileService()
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("weditor_test_\(UUID().uuidString).txt")
        
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        let testContent = "Hello WEditor!\nLine 2\nLine 3"
        try service.writeFile(content: testContent, to: testFile)
        
        let (content, encoding) = try service.readFile(at: testFile)
        
        XCTAssertEqual(content, testContent)
        XCTAssertEqual(encoding, .utf8)
    }
    
    func testFileServiceExists() throws {
        let service = FileService()
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("weditor_exists_\(UUID().uuidString).txt")
        
        XCTAssertFalse(service.fileExists(at: testFile))
        
        try service.writeFile(content: "test", to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        XCTAssertTrue(service.fileExists(at: testFile))
    }
    
    func testFileServiceIsTextFile() {
        let service = FileService()
        
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.swift")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.py")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.js")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.html")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.json")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.md")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/file.txt")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/Dockerfile")))
        XCTAssertTrue(service.isTextFile(at: URL(fileURLWithPath: "/test/Makefile")))
        XCTAssertFalse(service.isTextFile(at: URL(fileURLWithPath: "/test/file.png")))
        XCTAssertFalse(service.isTextFile(at: URL(fileURLWithPath: "/test/file.mp4")))
    }
    
    // MARK: - Extension Tests
    
    func testStringCountOccurrences() {
        XCTAssertEqual("Hello World Hello".countOccurrences(of: "Hello"), 2)
        XCTAssertEqual("aaa".countOccurrences(of: "a"), 3)
        XCTAssertEqual("test".countOccurrences(of: "x"), 0)
    }
    
    func testStringCountOccurrencesCaseInsensitive() {
        XCTAssertEqual("Hello hello HELLO".countOccurrences(of: "hello", caseSensitive: false), 3)
        XCTAssertEqual("Hello hello HELLO".countOccurrences(of: "hello", caseSensitive: true), 1)
    }
    
    func testStringLineAndColumn() {
        let text = "Hello\nWorld\nSwift"
        
        let (line0, col0) = text.lineAndColumn(at: 0)
        XCTAssertEqual(line0, 0)
        XCTAssertEqual(col0, 0)
        
        let (line1, col1) = text.lineAndColumn(at: 6)
        XCTAssertEqual(line1, 1)
        XCTAssertEqual(col1, 0)
        
        let (line2, col2) = text.lineAndColumn(at: 12)
        XCTAssertEqual(line2, 2)
        XCTAssertEqual(col2, 0)
    }
    
    func testStringIsValidFilename() {
        XCTAssertTrue("test.txt".isValidFilename)
        XCTAssertTrue("my-file_v2.swift".isValidFilename)
        XCTAssertFalse("".isValidFilename)
        XCTAssertFalse(".".isValidFilename)
        XCTAssertFalse("..".isValidFilename)
        XCTAssertFalse("test/file.txt".isValidFilename)
        XCTAssertFalse("test\\file.txt".isValidFilename)
    }
    
    func testStringTruncated() {
        XCTAssertEqual("Hello".truncated(to: 10), "Hello")
        XCTAssertEqual("Hello World!".truncated(to: 5), "Hell…")
    }
    
    func testIntLineNumberString() {
        XCTAssertEqual(1.lineNumberString(totalLines: 100), "  1")
        XCTAssertEqual(42.lineNumberString(totalLines: 100), " 42")
        XCTAssertEqual(100.lineNumberString(totalLines: 100), "100")
        XCTAssertEqual(5.lineNumberString(totalLines: 9), "5")
    }
    
    func testArraySafeSubscript() {
        let arr = [1, 2, 3]
        
        XCTAssertEqual(arr[safe: 0], 1)
        XCTAssertEqual(arr[safe: 2], 3)
        XCTAssertNil(arr[safe: 3])
        XCTAssertNil(arr[safe: -1])
    }
    
    // MARK: - AppState Tests
    
    func testAppStateNewDocument() {
        let appState = AppState()
        
        XCTAssertTrue(appState.documents.isEmpty)
        XCTAssertNil(appState.activeDocument)
        
        appState.newDocument()
        
        XCTAssertEqual(appState.documents.count, 1)
        XCTAssertNotNil(appState.activeDocument)
    }
    
    func testAppStateCloseDocument() {
        let appState = AppState()
        
        appState.newDocument()
        appState.newDocument()
        XCTAssertEqual(appState.documents.count, 2)
        
        let firstDoc = appState.documents[0]
        appState.closeDocument(firstDoc)
        
        XCTAssertEqual(appState.documents.count, 1)
    }
    
    func testAppStateDuplicateLine() {
        let appState = AppState()
        appState.newDocument()
        
        guard let doc = appState.activeDocument else {
            XCTFail("No active document")
            return
        }
        
        doc.updateContent("Line 1\nLine 2\nLine 3")
        doc.cursorPosition = CursorPosition(line: 1, column: 0)
        
        appState.duplicateCurrentLine()
        
        XCTAssertEqual(doc.lineCount, 4)
        XCTAssertEqual(doc.lines[1], "Line 2")
        XCTAssertEqual(doc.lines[2], "Line 2")
    }
    
    func testAppStateDeleteLine() {
        let appState = AppState()
        appState.newDocument()
        
        guard let doc = appState.activeDocument else {
            XCTFail("No active document")
            return
        }
        
        doc.updateContent("Line 1\nLine 2\nLine 3")
        doc.cursorPosition = CursorPosition(line: 1, column: 0)
        
        appState.deleteCurrentLine()
        
        XCTAssertEqual(doc.lineCount, 2)
        XCTAssertEqual(doc.lines[0], "Line 1")
        XCTAssertEqual(doc.lines[1], "Line 3")
    }
    
    func testAppStateMoveLineUp() {
        let appState = AppState()
        appState.newDocument()
        
        guard let doc = appState.activeDocument else {
            XCTFail("No active document")
            return
        }
        
        doc.updateContent("Line 1\nLine 2\nLine 3")
        doc.cursorPosition = CursorPosition(line: 1, column: 0)
        
        appState.moveLineUp()
        
        XCTAssertEqual(doc.lines[0], "Line 2")
        XCTAssertEqual(doc.lines[1], "Line 1")
        XCTAssertEqual(doc.cursorPosition.line, 0)
    }
    
    func testAppStateMoveLineDown() {
        let appState = AppState()
        appState.newDocument()
        
        guard let doc = appState.activeDocument else {
            XCTFail("No active document")
            return
        }
        
        doc.updateContent("Line 1\nLine 2\nLine 3")
        doc.cursorPosition = CursorPosition(line: 1, column: 0)
        
        appState.moveLineDown()
        
        XCTAssertEqual(doc.lines[1], "Line 3")
        XCTAssertEqual(doc.lines[2], "Line 2")
        XCTAssertEqual(doc.cursorPosition.line, 2)
    }
    
    func testAppStateColumnEditMode() {
        let appState = AppState()
        
        XCTAssertFalse(appState.isColumnEditMode)
        
        appState.isColumnEditMode = true
        XCTAssertTrue(appState.isColumnEditMode)
    }
}

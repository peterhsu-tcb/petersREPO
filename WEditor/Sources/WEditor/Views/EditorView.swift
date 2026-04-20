import SwiftUI

/// Container view that holds the editor with gutter and minimap
struct EditorContainerView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            // Gutter (line numbers)
            if settings.showLineNumbers {
                GutterView(document: document)
            }
            
            // Main editor
            EditorView(document: document)
            
            // Mini map
            if settings.showMiniMap {
                MiniMapView(document: document)
            }
        }
    }
}

/// Main text editor view using NSTextView wrapper
struct EditorView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Column edit mode indicator
            if appState.isColumnEditMode {
                HStack {
                    Image(systemName: "rectangle.split.3x1")
                        .foregroundColor(.accentColor)
                    Text("Column Edit Mode")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text("(⌘⌥Arrow to select, Delete/Type to edit)")
                        .font(.system(size: 11))
                        .foregroundColor(settings.currentTheme.textColor.opacity(0.5))
                    Spacer()
                    Button("Exit (⌘L)") {
                        appState.isColumnEditMode = false
                        document.columnSelection = nil
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(settings.currentTheme.gutterBackgroundColor)
            }
            
            // Editor content
            EditorTextView(document: document)
                .background(settings.currentTheme.backgroundColor)
        }
    }
}

/// SwiftUI wrapper for the text editing area
struct EditorTextView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    @EnvironmentObject var appState: AppState
    @State private var scrollOffset: CGFloat = 0
    
    private let highlightingService = SyntaxHighlightingService()
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(document.lines.enumerated()), id: \.offset) { lineIndex, line in
                    lineView(lineIndex: lineIndex, line: line)
                }
                
                // Extra space at bottom for scrolling
                Spacer()
                    .frame(height: 200)
            }
            .padding(.leading, 4)
            .padding(.trailing, 8)
        }
        .background(settings.currentTheme.backgroundColor)
        .overlay(
            ColumnEditKeyHandler(appState: appState)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }
    
    @ViewBuilder
    private func lineView(lineIndex: Int, line: String) -> some View {
        let theme = settings.currentTheme
        let isCurrentLine = lineIndex == document.cursorPosition.line
        let highlightedLine = highlightingService.highlightLine(line, lineIndex: lineIndex, language: document.language)
        
        HStack(spacing: 0) {
            // Line content with syntax highlighting
            highlightedTextView(highlightedLine: highlightedLine, theme: theme)
            
            Spacer(minLength: 0)
        }
        .frame(height: settings.fontSize * settings.lineSpacing)
        .background(
            isCurrentLine && settings.highlightCurrentLine ?
                theme.currentLineHighlight : Color.clear
        )
        .background(columnSelectionBackground(lineIndex: lineIndex))
    }
    
    @ViewBuilder
    private func highlightedTextView(highlightedLine: HighlightedLine, theme: EditorTheme) -> some View {
        let text = highlightedLine.text
        let fontDesign: Font.Design = .monospaced
        
        if highlightedLine.tokens.isEmpty {
            Text(text.isEmpty ? " " : text)
                .font(.system(size: settings.fontSize, design: fontDesign))
                .foregroundColor(theme.textColor)
        } else {
            // Build attributed text using SwiftUI Text concatenation
            buildHighlightedText(highlightedLine: highlightedLine, theme: theme)
        }
    }
    
    private func buildHighlightedText(highlightedLine: HighlightedLine, theme: EditorTheme) -> Text {
        let text = highlightedLine.text
        let tokens = highlightedLine.tokens
        var result = Text("")
        var lastEnd = text.startIndex
        
        for token in tokens {
            guard let rangeStart = Range(token.range, in: text) else { continue }
            
            // Add unhighlighted text before this token
            if lastEnd < rangeStart.lowerBound {
                let plainText = String(text[lastEnd..<rangeStart.lowerBound])
                result = result + Text(plainText)
                    .font(.system(size: settings.fontSize, design: .monospaced))
                    .foregroundColor(theme.textColor)
            }
            
            // Add highlighted token
            let tokenText = String(text[rangeStart])
            let color = theme.color(for: token.tokenType)
            var tokenView = Text(tokenText)
                .font(.system(size: settings.fontSize, design: .monospaced))
                .foregroundColor(color)
            
            if token.tokenType == .keyword || token.tokenType == .heading || token.tokenType == .bold {
                tokenView = tokenView.bold()
            }
            if token.tokenType == .comment || token.tokenType == .italic {
                tokenView = tokenView.italic()
            }
            
            result = result + tokenView
            lastEnd = rangeStart.upperBound
        }
        
        // Add remaining text
        if lastEnd < text.endIndex {
            let remaining = String(text[lastEnd...])
            result = result + Text(remaining)
                .font(.system(size: settings.fontSize, design: .monospaced))
                .foregroundColor(theme.textColor)
        }
        
        if text.isEmpty {
            result = Text(" ")
                .font(.system(size: settings.fontSize, design: .monospaced))
        }
        
        return result
    }
    
    @ViewBuilder
    private func columnSelectionBackground(lineIndex: Int) -> some View {
        if let colSel = document.columnSelection,
           lineIndex >= colSel.topLine && lineIndex <= colSel.bottomLine {
            GeometryReader { geo in
                let charWidth = settings.fontSize * 0.6
                let startX = CGFloat(colSel.leftColumn) * charWidth
                let width = CGFloat(colSel.width) * charWidth
                
                Rectangle()
                    .fill(settings.currentTheme.columnSelectionColor)
                    .frame(width: max(width, 2), height: geo.size.height)
                    .offset(x: startX)
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - Column Edit Key Handler

#if canImport(AppKit)
import AppKit

/// NSViewRepresentable that captures keyboard events for column edit mode
struct ColumnEditKeyHandler: NSViewRepresentable {
    let appState: AppState
    
    func makeNSView(context: Context) -> ColumnEditKeyView {
        let view = ColumnEditKeyView()
        view.appState = appState
        return view
    }
    
    func updateNSView(_ nsView: ColumnEditKeyView, context: Context) {
        nsView.appState = appState
    }
}

/// NSView subclass that handles keyboard events for column editing
class ColumnEditKeyView: NSView {
    var appState: AppState?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard let appState = appState, appState.isColumnEditMode else {
            super.keyDown(with: event)
            return
        }
        
        // Handle delete/backspace in column mode
        if event.keyCode == 51 { // Backspace
            appState.columnBackspace()
            return
        }
        
        // Handle forward delete
        if event.keyCode == 117 { // Forward Delete
            appState.columnDeleteSelection()
            return
        }
        
        // Handle typed characters in column mode
        if let chars = event.characters, !chars.isEmpty,
           !event.modifierFlags.contains(.command),
           !event.modifierFlags.contains(.control) {
            let char = chars.first!
            if char.isASCII && (char.isLetter || char.isNumber || char.isPunctuation || char.isSymbol || char == " ") {
                appState.columnTypeText(String(char))
                return
            }
        }
        
        super.keyDown(with: event)
    }
}
#endif

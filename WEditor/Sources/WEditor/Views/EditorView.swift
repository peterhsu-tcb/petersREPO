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
                    Text("(Alt+Drag or Alt+Shift+Arrow)")
                        .font(.system(size: 11))
                        .foregroundColor(settings.currentTheme.textColor.opacity(0.5))
                    Spacer()
                    Button("Exit") {
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
        
        if highlightedLine.tokens.isEmpty {
            Text(text.isEmpty ? " " : text)
                .font(.system(size: settings.fontSize, design: .monospaced))
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

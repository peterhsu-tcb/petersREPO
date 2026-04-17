import SwiftUI

/// Find and Replace bar view
struct FindReplaceView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings
    @State private var searchText: String = ""
    @State private var replaceText: String = ""
    @State private var caseSensitive: Bool = false
    @State private var wholeWord: Bool = false
    @State private var useRegex: Bool = false
    @State private var matchCount: Int = 0
    @State private var currentMatchIndex: Int = 0
    
    private let searchService = SearchReplaceService()
    
    var body: some View {
        let theme = settings.currentTheme
        
        VStack(spacing: 4) {
            // Search row
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textColor.opacity(0.5))
                    .frame(width: 16)
                
                TextField("Find", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.textColor)
                    .frame(minWidth: 200)
                    .onSubmit {
                        findNext()
                    }
                    .onChange(of: searchText) { _ in
                        updateMatchCount()
                    }
                
                // Match count
                if !searchText.isEmpty {
                    Text("\(matchCount) matches")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textColor.opacity(0.5))
                }
                
                // Search options
                Toggle("Aa", isOn: $caseSensitive)
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: caseSensitive ? .bold : .regular))
                    .help("Case Sensitive")
                
                Toggle("W", isOn: $wholeWord)
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: wholeWord ? .bold : .regular))
                    .help("Whole Word")
                
                Toggle(".*", isOn: $useRegex)
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: useRegex ? .bold : .regular, design: .monospaced))
                    .help("Regular Expression")
                
                Divider().frame(height: 16)
                
                // Navigation buttons
                Button(action: findPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .help("Previous Match (⇧⌘G)")
                
                Button(action: findNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .help("Next Match (⌘G)")
                
                Spacer()
                
                // Close button
                Button(action: {
                    appState.showFindReplace = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            
            // Replace row (toggleable)
            if appState.showReplace {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundColor(theme.textColor.opacity(0.5))
                        .frame(width: 16)
                    
                    TextField("Replace", text: $replaceText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(theme.textColor)
                        .frame(minWidth: 200)
                    
                    Button("Replace") {
                        replaceCurrent()
                    }
                    .buttonStyle(.plain)
                    .help("Replace (⌘⇧1)")
                    
                    Button("Replace All") {
                        replaceAll()
                    }
                    .buttonStyle(.plain)
                    .help("Replace All (⌘⌥Enter)")
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.gutterBackgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.gutterTextColor.opacity(0.2)),
            alignment: .top
        )
    }
    
    private var searchOptions: SearchOptions {
        SearchOptions(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            useRegex: useRegex
        )
    }
    
    private func updateMatchCount() {
        guard let doc = appState.activeDocument else { return }
        let matches = searchService.findAll(in: doc.lines, searchText: searchText, options: searchOptions)
        matchCount = matches.count
        appState.searchMatches = matches
    }
    
    private func findNext() {
        guard let doc = appState.activeDocument else { return }
        if let match = searchService.findNext(
            in: doc.lines,
            searchText: searchText,
            fromLine: doc.cursorPosition.line,
            fromColumn: doc.cursorPosition.column,
            options: searchOptions
        ) {
            doc.cursorPosition = CursorPosition(line: match.line, column: match.column)
            appState.currentSearchMatch = match
        }
    }
    
    private func findPrevious() {
        guard let doc = appState.activeDocument else { return }
        if let match = searchService.findPrevious(
            in: doc.lines,
            searchText: searchText,
            fromLine: doc.cursorPosition.line,
            fromColumn: doc.cursorPosition.column,
            options: searchOptions
        ) {
            doc.cursorPosition = CursorPosition(line: match.line, column: match.column)
            appState.currentSearchMatch = match
        }
    }
    
    private func replaceCurrent() {
        guard let doc = appState.activeDocument,
              let match = appState.currentSearchMatch else { return }
        
        var lines = doc.lines
        searchService.replace(in: &lines, match: match, replacement: replaceText)
        doc.updateContent(lines.joined(separator: "\n"))
        updateMatchCount()
        findNext()
    }
    
    private func replaceAll() {
        guard let doc = appState.activeDocument else { return }
        
        var lines = doc.lines
        let count = searchService.replaceAll(in: &lines, searchText: searchText, replacement: replaceText, options: searchOptions)
        doc.updateContent(lines.joined(separator: "\n"))
        updateMatchCount()
        
        appState.statusMessage = "Replaced \(count) occurrences"
    }
}

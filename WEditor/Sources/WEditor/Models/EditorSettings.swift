import Foundation

/// Editor settings and preferences
class EditorSettings: ObservableObject {
    @Published var fontSize: CGFloat = 14
    @Published var fontName: String = "Menlo"
    @Published var tabWidth: Int = 4
    @Published var useSpacesForTabs: Bool = true
    @Published var showLineNumbers: Bool = true
    @Published var showMiniMap: Bool = true
    @Published var wordWrap: Bool = false
    @Published var showWhitespace: Bool = false
    @Published var showIndentGuides: Bool = true
    @Published var highlightCurrentLine: Bool = true
    @Published var autoIndent: Bool = true
    @Published var matchBrackets: Bool = true
    @Published var autoCloseBrackets: Bool = true
    @Published var lineSpacing: CGFloat = 1.2
    @Published var selectedThemeId: String = EditorTheme.defaultDark.id
    @Published var recentFiles: [URL] = []
    @Published var maxRecentFiles: Int = 20
    @Published var autoSaveEnabled: Bool = false
    @Published var autoSaveInterval: TimeInterval = 30
    @Published var showStatusBar: Bool = true
    @Published var showToolbar: Bool = true
    
    /// Current theme based on selectedThemeId
    var currentTheme: EditorTheme {
        EditorTheme.allThemes.first { $0.id == selectedThemeId } ?? .defaultDark
    }
    
    /// Tab string based on settings
    var tabString: String {
        useSpacesForTabs ? String(repeating: " ", count: tabWidth) : "\t"
    }
    
    /// Add file to recent files
    func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
    }
}

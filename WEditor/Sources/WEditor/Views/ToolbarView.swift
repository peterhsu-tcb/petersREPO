import SwiftUI

/// Toolbar view with icon buttons for common editor functions
struct ToolbarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        let theme = settings.currentTheme
        
        HStack(spacing: 2) {
            // MARK: - File Operations
            
            ToolbarButton(icon: "doc.badge.plus", tooltip: "New File (⌘N)") {
                appState.newDocument()
            }
            
            ToolbarButton(icon: "folder", tooltip: "Open File (⌘O)") {
                appState.showOpenPanel()
            }
            
            ToolbarButton(icon: "square.and.arrow.down", tooltip: "Save (⌘S)") {
                appState.saveActiveDocument()
            }
            .disabled(appState.activeDocument == nil)
            
            ToolbarDivider()
            
            // MARK: - Undo / Redo
            
            ToolbarButton(icon: "arrow.uturn.backward", tooltip: "Undo (⌘Z)") {
                appState.activeDocument?.undo()
            }
            .disabled(appState.activeDocument == nil || appState.activeDocument?.undoStack.isEmpty == true)
            
            ToolbarButton(icon: "arrow.uturn.forward", tooltip: "Redo (⌘⇧Z)") {
                appState.activeDocument?.redo()
            }
            .disabled(appState.activeDocument == nil || appState.activeDocument?.redoStack.isEmpty == true)
            
            ToolbarDivider()
            
            // MARK: - Find / Replace
            
            ToolbarButton(icon: "magnifyingglass", tooltip: "Find (⌘F)") {
                appState.showFindReplace = true
                appState.showReplace = false
            }
            
            ToolbarButton(icon: "arrow.left.arrow.right", tooltip: "Find & Replace (⌘⌥F)") {
                appState.showFindReplace = true
                appState.showReplace = true
            }
            
            ToolbarDivider()
            
            // MARK: - Font Size
            
            ToolbarButton(icon: "textformat.size.smaller", tooltip: "Decrease Font Size (⌘-)") {
                settings.fontSize = max(settings.fontSize - 1, 8)
            }
            
            Text("\(Int(settings.fontSize))pt")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.textColor.opacity(0.7))
                .frame(width: 32)
            
            ToolbarButton(icon: "textformat.size.larger", tooltip: "Increase Font Size (⌘+)") {
                settings.fontSize = min(settings.fontSize + 1, 32)
            }
            
            ToolbarDivider()
            
            // MARK: - View Toggles
            
            ToolbarToggle(icon: "list.number", tooltip: "Line Numbers", isOn: $settings.showLineNumbers)
            
            ToolbarToggle(icon: "sidebar.right", tooltip: "Mini Map", isOn: $settings.showMiniMap)
            
            ToolbarToggle(icon: "text.word.spacing", tooltip: "Word Wrap (⌘⌥Z)", isOn: $settings.wordWrap)
            
            ToolbarToggle(icon: "light.max", tooltip: "Highlight Current Line", isOn: $settings.highlightCurrentLine)
            
            ToolbarDivider()
            
            // MARK: - Column Edit Mode
            
            ToolbarButton(
                icon: "rectangle.split.3x1",
                tooltip: "Column Edit Mode (⌘L)",
                isActive: appState.isColumnEditMode
            ) {
                appState.isColumnEditMode.toggle()
            }
            
            // MARK: - HTML Mode (only when HTML document is active)
            
            if appState.activeDocument?.isHTML == true {
                ToolbarDivider()
                
                HTMLModeToolbarGroup()
            }
            
            Spacer()
            
            // MARK: - Settings
            
            ToolbarDivider()
            
            // Theme toggle (dark/light)
            ToolbarButton(
                icon: theme.isDark ? "moon.fill" : "sun.max.fill",
                tooltip: "Switch Theme"
            ) {
                // Cycle through available themes
                let themes = EditorTheme.allThemes
                if let currentIndex = themes.firstIndex(where: { $0.id == settings.selectedThemeId }) {
                    let nextIndex = (currentIndex + 1) % themes.count
                    settings.selectedThemeId = themes[nextIndex].id
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.gutterBackgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.gutterTextColor.opacity(0.2)),
            alignment: .bottom
        )
    }
}

/// HTML mode buttons shown only for HTML documents
struct HTMLModeToolbarGroup: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if let doc = appState.activeDocument, doc.isHTML {
            ToolbarButton(
                icon: "chevron.left.forwardslash.chevron.right",
                tooltip: "Source View (⌘⌥1)",
                isActive: doc.htmlEditMode == .source
            ) {
                doc.htmlEditMode = .source
            }
            
            ToolbarButton(
                icon: "globe",
                tooltip: "Visual Editor (⌘⌥2)",
                isActive: doc.htmlEditMode == .visual
            ) {
                doc.htmlEditMode = .visual
            }
            
            ToolbarButton(
                icon: "rectangle.split.2x1",
                tooltip: "Split View (⌘⌥3)",
                isActive: doc.htmlEditMode == .split
            ) {
                doc.htmlEditMode = .split
            }
        }
    }
}

// MARK: - Toolbar Components

/// A single toolbar icon button
struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var isActive: Bool = false
    let action: () -> Void
    
    @EnvironmentObject var settings: EditorSettings
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        let theme = settings.currentTheme
        
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 24)
                .foregroundColor(
                    isActive ? .accentColor :
                    isEnabled ? theme.textColor.opacity(0.8) :
                    theme.textColor.opacity(0.3)
                )
                .background(
                    isActive ?
                        theme.textColor.opacity(0.1) :
                        Color.clear
                )
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

/// A toolbar toggle button (bound to a Bool binding)
struct ToolbarToggle: View {
    let icon: String
    let tooltip: String
    @Binding var isOn: Bool
    
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        ToolbarButton(icon: icon, tooltip: tooltip, isActive: isOn) {
            isOn.toggle()
        }
    }
}

/// A vertical divider in the toolbar
struct ToolbarDivider: View {
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 4)
    }
}

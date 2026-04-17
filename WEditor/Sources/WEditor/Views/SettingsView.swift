import SwiftUI

/// Settings view for editor preferences
struct SettingsView: View {
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            EditorSettingsView()
                .tabItem {
                    Label("Editor", systemImage: "doc.text")
                }
            
            ThemeSettingsView()
                .tabItem {
                    Label("Themes", systemImage: "paintpalette")
                }
        }
        .frame(width: 480, height: 400)
        .padding()
    }
}

/// General settings tab
struct GeneralSettingsView: View {
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        Form {
            Section("File") {
                Toggle("Auto-save", isOn: $settings.autoSaveEnabled)
                
                if settings.autoSaveEnabled {
                    HStack {
                        Text("Save interval:")
                        TextField("", value: $settings.autoSaveInterval, format: .number)
                            .frame(width: 60)
                        Text("seconds")
                    }
                }
            }
            
            Section("Interface") {
                Toggle("Show Status Bar", isOn: $settings.showStatusBar)
                Toggle("Show Toolbar", isOn: $settings.showToolbar)
                Toggle("Show Mini Map", isOn: $settings.showMiniMap)
                Toggle("Show Line Numbers", isOn: $settings.showLineNumbers)
            }
        }
        .padding()
    }
}

/// Editor settings tab
struct EditorSettingsView: View {
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        Form {
            Section("Font") {
                HStack {
                    Text("Font:")
                    Picker("", selection: $settings.fontName) {
                        Text("Menlo").tag("Menlo")
                        Text("Monaco").tag("Monaco")
                        Text("SF Mono").tag("SF Mono")
                        Text("Courier New").tag("Courier New")
                        Text("Andale Mono").tag("Andale Mono")
                    }
                    .frame(width: 150)
                }
                
                HStack {
                    Text("Size:")
                    Slider(value: $settings.fontSize, in: 8...32, step: 1)
                    Text("\(Int(settings.fontSize)) pt")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Line Spacing:")
                    Slider(value: $settings.lineSpacing, in: 1.0...2.0, step: 0.1)
                    Text(String(format: "%.1f", settings.lineSpacing))
                        .frame(width: 30)
                }
            }
            
            Section("Editing") {
                HStack {
                    Text("Tab Width:")
                    Picker("", selection: $settings.tabWidth) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .frame(width: 80)
                }
                
                Toggle("Use Spaces for Tabs", isOn: $settings.useSpacesForTabs)
                Toggle("Word Wrap", isOn: $settings.wordWrap)
                Toggle("Auto Indent", isOn: $settings.autoIndent)
                Toggle("Match Brackets", isOn: $settings.matchBrackets)
                Toggle("Auto Close Brackets", isOn: $settings.autoCloseBrackets)
            }
            
            Section("Display") {
                Toggle("Highlight Current Line", isOn: $settings.highlightCurrentLine)
                Toggle("Show Whitespace", isOn: $settings.showWhitespace)
                Toggle("Show Indent Guides", isOn: $settings.showIndentGuides)
            }
        }
        .padding()
    }
}

/// Theme settings tab
struct ThemeSettingsView: View {
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Theme")
                .font(.headline)
            
            ForEach(EditorTheme.allThemes, id: \.id) { theme in
                HStack {
                    // Theme preview
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.backgroundColor)
                        .frame(width: 80, height: 50)
                        .overlay(
                            VStack(alignment: .leading, spacing: 2) {
                                Text("fn")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(theme.color(for: .keyword))
                                Text("\"str\"")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(theme.color(for: .string))
                                Text("// comment")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(theme.color(for: .comment))
                            }
                            .padding(4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    settings.selectedThemeId == theme.id ? Color.accentColor : Color.gray.opacity(0.3),
                                    lineWidth: settings.selectedThemeId == theme.id ? 2 : 1
                                )
                        )
                    
                    VStack(alignment: .leading) {
                        Text(theme.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(theme.isDark ? "Dark" : "Light")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if settings.selectedThemeId == theme.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    settings.selectedThemeId = theme.id
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .padding()
    }
}

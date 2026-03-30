import SwiftUI

/// Settings/Preferences view
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("terminalApp") private var terminalApp: String = "Terminal"
    @AppStorage("showHiddenByDefault") private var showHiddenByDefault: Bool = false
    @AppStorage("confirmDelete") private var confirmDelete: Bool = true
    @AppStorage("useTrash") private var useTrash: Bool = true
    @AppStorage("editorApp") private var editorApp: String = "TextEdit"
    @AppStorage("theme") private var theme: String = "system"
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                showHiddenByDefault: $showHiddenByDefault,
                confirmDelete: $confirmDelete,
                useTrash: $useTrash,
                theme: $theme
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppsSettingsView(
                terminalApp: $terminalApp,
                editorApp: $editorApp
            )
            .tabItem {
                Label("Applications", systemImage: "app")
            }
            
            KeyboardSettingsView()
            .tabItem {
                Label("Keyboard", systemImage: "keyboard")
            }
        }
        .frame(width: 500, height: 350)
    }
}

/// General settings tab
struct GeneralSettingsView: View {
    @Binding var showHiddenByDefault: Bool
    @Binding var confirmDelete: Bool
    @Binding var useTrash: Bool
    @Binding var theme: String
    
    var body: some View {
        Form {
            Section("File Browsing") {
                Toggle("Show hidden files by default", isOn: $showHiddenByDefault)
            }
            
            Section("File Operations") {
                Toggle("Confirm before deleting", isOn: $confirmDelete)
                Toggle("Move to Trash instead of permanent delete", isOn: $useTrash)
            }
            
            Section("Appearance") {
                Picker("Theme:", selection: $theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Applications settings tab
struct AppsSettingsView: View {
    @Binding var terminalApp: String
    @Binding var editorApp: String
    
    var body: some View {
        Form {
            Section("Terminal") {
                Picker("Terminal application:", selection: $terminalApp) {
                    Text("Terminal").tag("Terminal")
                    Text("iTerm").tag("iTerm")
                }
            }
            
            Section("Text Editor") {
                Picker("Text editor:", selection: $editorApp) {
                    Text("TextEdit").tag("TextEdit")
                    Text("Xcode").tag("Xcode")
                    Text("VS Code").tag("Visual Studio Code")
                    Text("Sublime Text").tag("Sublime Text")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Keyboard shortcuts settings tab
struct KeyboardSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(key: "F1", description: "Help")
                    ShortcutRow(key: "F2", description: "Rename selected item")
                    ShortcutRow(key: "F3", description: "View selected file")
                    ShortcutRow(key: "F4", description: "Edit selected file")
                    ShortcutRow(key: "F5", description: "Copy selected items")
                    ShortcutRow(key: "F6", description: "Move selected items")
                    ShortcutRow(key: "F7", description: "Create new folder")
                    ShortcutRow(key: "F8", description: "Delete selected items")
                    ShortcutRow(key: "F9", description: "Open terminal")
                    ShortcutRow(key: "F10", description: "Quit application")
                    
                    Divider()
                    
                    ShortcutRow(key: "⌘N", description: "New window")
                    ShortcutRow(key: "⌘⇧N", description: "New folder")
                    ShortcutRow(key: "⌘⌥N", description: "New file")
                    ShortcutRow(key: "⌘R", description: "Refresh")
                    ShortcutRow(key: "⌘F", description: "Search")
                    ShortcutRow(key: "⌘G", description: "Go to path")
                    ShortcutRow(key: "⌘⇧.", description: "Toggle hidden files")
                    ShortcutRow(key: "⌘⇧T", description: "Open terminal here")
                    ShortcutRow(key: "Tab", description: "Switch panes")
                    ShortcutRow(key: "⌘[", description: "Go back")
                    ShortcutRow(key: "⌘]", description: "Go forward")
                    ShortcutRow(key: "⌘↑", description: "Go to parent folder")
                }
            }
        }
        .padding()
    }
}

/// Single shortcut row
struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 80, alignment: .trailing)
            
            Text(description)
                .foregroundColor(.secondary)
        }
    }
}

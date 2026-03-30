import SwiftUI

/// Settings view for application preferences
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            KeyboardSettingsView()
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }
            
            FileTypesSettingsView()
                .tabItem {
                    Label("File Types", systemImage: "doc")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("showHiddenByDefault") private var showHiddenByDefault = false
    @AppStorage("confirmDelete") private var confirmDelete = true
    @AppStorage("moveToTrashByDefault") private var moveToTrashByDefault = true
    @AppStorage("rememberLastDirectory") private var rememberLastDirectory = true
    @AppStorage("doubleClickAction") private var doubleClickAction = "open"
    
    var body: some View {
        Form {
            Section("File Display") {
                Toggle("Show hidden files by default", isOn: $showHiddenByDefault)
            }
            
            Section("File Operations") {
                Toggle("Confirm before deleting files", isOn: $confirmDelete)
                Toggle("Move to Trash by default (instead of permanent delete)", isOn: $moveToTrashByDefault)
            }
            
            Section("Startup") {
                Toggle("Remember last visited directory", isOn: $rememberLastDirectory)
            }
            
            Section("Double-Click Action") {
                Picker("When double-clicking a file:", selection: $doubleClickAction) {
                    Text("Open with default application").tag("open")
                    Text("Open in editor").tag("editor")
                    Text("Quick Look preview").tag("preview")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @AppStorage("fontSize") private var fontSize = 13.0
    @AppStorage("showFileIcons") private var showFileIcons = true
    @AppStorage("alternateRowColors") private var alternateRowColors = true
    @AppStorage("dateFormat") private var dateFormat = "short"
    @AppStorage("sizeFormat") private var sizeFormat = "auto"
    
    var body: some View {
        Form {
            Section("Text") {
                Slider(value: $fontSize, in: 10...18, step: 1) {
                    Text("Font size: \(Int(fontSize))pt")
                }
            }
            
            Section("File List") {
                Toggle("Show file type icons", isOn: $showFileIcons)
                Toggle("Alternate row colors", isOn: $alternateRowColors)
            }
            
            Section("Date Format") {
                Picker("Date format:", selection: $dateFormat) {
                    Text("Short (12/31/24)").tag("short")
                    Text("Medium (Dec 31, 2024)").tag("medium")
                    Text("Long (December 31, 2024)").tag("long")
                    Text("Relative (2 days ago)").tag("relative")
                }
            }
            
            Section("Size Format") {
                Picker("Size format:", selection: $sizeFormat) {
                    Text("Auto (KB, MB, GB)").tag("auto")
                    Text("Always bytes").tag("bytes")
                    Text("Always KB").tag("kb")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Keyboard Settings

struct KeyboardSettingsView: View {
    var body: some View {
        Form {
            Section("Function Keys") {
                ForEach(DefaultCommands.functionKeyCommands) { command in
                    HStack {
                        Text(command.id.rawValue)
                            .frame(width: 40, alignment: .leading)
                            .foregroundColor(.secondary)
                        Text(command.label)
                        Spacer()
                        Image(systemName: command.icon)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Common Shortcuts") {
                ShortcutRow(shortcut: "⌘C", action: "Copy")
                ShortcutRow(shortcut: "⌘V", action: "Paste")
                ShortcutRow(shortcut: "⌘X", action: "Cut")
                ShortcutRow(shortcut: "⌘A", action: "Select All")
                ShortcutRow(shortcut: "⌘⌫", action: "Delete")
                ShortcutRow(shortcut: "⌘N", action: "New Folder")
                ShortcutRow(shortcut: "⌘R", action: "Refresh")
                ShortcutRow(shortcut: "⌘F", action: "Find")
                ShortcutRow(shortcut: "⌘G", action: "Go to Directory")
                ShortcutRow(shortcut: "Tab", action: "Switch Panels")
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let shortcut: String
    let action: String
    
    var body: some View {
        HStack {
            Text(shortcut)
                .frame(width: 60, alignment: .leading)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
            Text(action)
            Spacer()
        }
    }
}

// MARK: - File Types Settings

struct FileTypesSettingsView: View {
    var body: some View {
        Form {
            Section("File Type Colors") {
                FileTypeColorRow(type: "Text files", color: .gray, extensions: "txt, md, log")
                FileTypeColorRow(type: "Images", color: .purple, extensions: "jpg, png, gif")
                FileTypeColorRow(type: "Videos", color: .pink, extensions: "mp4, mov, avi")
                FileTypeColorRow(type: "Audio", color: .orange, extensions: "mp3, wav, aac")
                FileTypeColorRow(type: "Archives", color: .brown, extensions: "zip, tar, gz")
                FileTypeColorRow(type: "Code", color: .green, extensions: "swift, py, js")
                FileTypeColorRow(type: "Executables", color: .red, extensions: "app, exe")
            }
            
            Section("External Applications") {
                HStack {
                    Text("Default text editor:")
                    Spacer()
                    Text("TextEdit")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Default terminal:")
                    Spacer()
                    Text("Terminal.app")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct FileTypeColorRow: View {
    let type: String
    let color: Color
    let extensions: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(type)
            Spacer()
            Text(extensions)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

import SwiftUI
import AppKit  // Using native macOS/C API (NSColor) for reliable color rendering

/// Settings view for application preferences
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("ignoreWhitespace") private var ignoreWhitespace = false
    @AppStorage("ignoreCase") private var ignoreCase = false
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @AppStorage("recursiveComparison") private var recursiveComparison = true
    @AppStorage("fontSizeOffset") private var fontSizeOffset = 0
    @AppStorage("selectedTheme") private var selectedTheme = "system"
    @AppStorage("lineDiffColor") private var lineDiffColor = "blue"
    @AppStorage("charDiffColor") private var charDiffColor = "red"
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                ignoreWhitespace: $ignoreWhitespace,
                ignoreCase: $ignoreCase,
                showHiddenFiles: $showHiddenFiles,
                recursiveComparison: $recursiveComparison
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppearanceSettingsView(
                fontSizeOffset: $fontSizeOffset,
                selectedTheme: $selectedTheme,
                lineDiffColor: $lineDiffColor,
                charDiffColor: $charDiffColor
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            FileTypesSettingsView()
            .tabItem {
                Label("File Types", systemImage: "doc.badge.gearshape")
            }
        }
        .frame(width: 450, height: 380)
        .padding()
    }
}

/// General settings tab
struct GeneralSettingsView: View {
    @Binding var ignoreWhitespace: Bool
    @Binding var ignoreCase: Bool
    @Binding var showHiddenFiles: Bool
    @Binding var recursiveComparison: Bool
    
    var body: some View {
        Form {
            Section("Comparison Options") {
                Toggle("Ignore whitespace differences", isOn: $ignoreWhitespace)
                Toggle("Ignore case differences", isOn: $ignoreCase)
            }
            
            Section("Folder Comparison") {
                Toggle("Show hidden files", isOn: $showHiddenFiles)
                Toggle("Recursive comparison", isOn: $recursiveComparison)
            }
        }
        .formStyle(.grouped)
    }
}

/// Appearance settings tab
struct AppearanceSettingsView: View {
    @Binding var fontSizeOffset: Int
    @Binding var selectedTheme: String
    @Binding var lineDiffColor: String
    @Binding var charDiffColor: String
    
    private let themes = ["system", "light", "dark"]
    private let colorOptions = ["blue", "red", "green", "orange", "purple", "yellow", "cyan", "magenta"]
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Color scheme:", selection: $selectedTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
            
            Section("Font") {
                HStack {
                    Text("Font size adjustment:")
                    Stepper(value: $fontSizeOffset, in: -4...8) {
                        Text("\(fontSizeOffset > 0 ? "+" : "")\(fontSizeOffset)")
                            .monospacedDigit()
                    }
                }
                
                Text("Preview: The quick brown fox jumps over the lazy dog")
                    .font(.system(size: CGFloat(14 + fontSizeOffset), design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Section("Diff Highlighting Colors") {
                HStack {
                    Text("Line-level diff (background):")
                    Picker("", selection: $lineDiffColor) {
                        ForEach(colorOptions, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(colorFromName(color))
                                    .frame(width: 12, height: 12)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    .frame(width: 120)
                }
                
                HStack {
                    Text("Character-level diff (text):")
                    Picker("", selection: $charDiffColor) {
                        ForEach(colorOptions, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(colorFromName(color))
                                    .frame(width: 12, height: 12)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    .frame(width: 120)
                }
                
                // Preview of diff highlighting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview:")
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 0) {
                        Text("Line background: ")
                            .foregroundColor(.secondary)
                        Text("changed line")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(colorFromName(lineDiffColor).opacity(0.3))
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 0) {
                        Text("Character diff: ")
                            .foregroundColor(.secondary)
                        Text("different")
                            .foregroundColor(colorFromName(charDiffColor))
                            .fontWeight(.medium)
                    }
                }
                .font(.system(.body, design: .monospaced))
                
                Button("Reset Colors to Defaults") {
                    lineDiffColor = "blue"
                    charDiffColor = "red"
                }
            }
        }
        .formStyle(.grouped)
    }
    
    /// Convert color name to Color using native macOS NSColor for reliable rendering
    private func colorFromName(_ name: String) -> Color {
        let nsColor: NSColor
        switch name {
        case "blue":
            nsColor = NSColor.systemBlue
        case "red":
            nsColor = NSColor.systemRed
        case "green":
            nsColor = NSColor.systemGreen
        case "orange":
            nsColor = NSColor.systemOrange
        case "purple":
            nsColor = NSColor.systemPurple
        case "yellow":
            nsColor = NSColor.systemYellow
        case "cyan":
            nsColor = NSColor.cyan
        case "magenta":
            nsColor = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
        default:
            nsColor = NSColor.systemBlue
        }
        return Color(nsColor: nsColor)
    }
}

/// File types settings tab
struct FileTypesSettingsView: View {
    @AppStorage("textExtensions") private var textExtensions = "txt,md,swift,py,js,ts,html,css,json,xml,yaml,yml"
    @AppStorage("binaryExtensions") private var binaryExtensions = "png,jpg,jpeg,gif,pdf,zip,tar,gz,exe,app,dmg"
    
    var body: some View {
        Form {
            Section("Text Files") {
                TextField("Extensions (comma-separated):", text: $textExtensions)
                Text("Files with these extensions will be compared as text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Binary Files") {
                TextField("Extensions (comma-separated):", text: $binaryExtensions)
                Text("Files with these extensions will be compared as binary")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("Reset to Defaults") {
                    textExtensions = "txt,md,swift,py,js,ts,html,css,json,xml,yaml,yml"
                    binaryExtensions = "png,jpg,jpeg,gif,pdf,zip,tar,gz,exe,app,dmg"
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

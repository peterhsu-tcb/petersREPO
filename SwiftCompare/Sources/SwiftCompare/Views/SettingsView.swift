import SwiftUI

/// Settings view for application preferences
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("ignoreWhitespace") private var ignoreWhitespace = false
    @AppStorage("ignoreCase") private var ignoreCase = false
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @AppStorage("recursiveComparison") private var recursiveComparison = true
    @AppStorage("fontSizeOffset") private var fontSizeOffset = 0
    @AppStorage("selectedTheme") private var selectedTheme = "system"
    @AppStorage("matchingCharColor") private var matchingCharColor = "blue"
    @AppStorage("differentCharColor") private var differentCharColor = "red"
    
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
                matchingCharColor: $matchingCharColor,
                differentCharColor: $differentCharColor
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            FileTypesSettingsView()
            .tabItem {
                Label("File Types", systemImage: "doc.badge.gearshape")
            }
        }
        .frame(width: 450, height: 300)
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
    @Binding var matchingCharColor: String
    @Binding var differentCharColor: String
    
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
            
            Section("Character-Level Diff Colors") {
                HStack {
                    Text("Matching characters:")
                    Picker("", selection: $matchingCharColor) {
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
                    Text("Different characters:")
                    Picker("", selection: $differentCharColor) {
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
                
                // Preview of character-level diff
                HStack(spacing: 0) {
                    Text("Preview: ")
                        .foregroundColor(.secondary)
                    Text("matching")
                        .foregroundColor(colorFromName(matchingCharColor))
                    Text(" vs ")
                        .foregroundColor(.secondary)
                    Text("different")
                        .foregroundColor(colorFromName(differentCharColor))
                }
                .font(.system(.body, design: .monospaced))
            }
            
            Section("Line Colors") {
                HStack {
                    ColorLegendItem(color: .green.opacity(0.15), label: "Added lines")
                    Spacer()
                    ColorLegendItem(color: .red.opacity(0.15), label: "Removed lines")
                    Spacer()
                    ColorLegendItem(color: .orange.opacity(0.15), label: "Modified lines")
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "magenta": return Color(red: 1, green: 0, blue: 1)
        default: return .blue
        }
    }
}

/// Color legend item
struct ColorLegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
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

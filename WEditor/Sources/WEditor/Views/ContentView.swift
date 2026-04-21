import SwiftUI
import UniformTypeIdentifiers

/// Main content view with tab bar and editor area
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            if settings.showToolbar {
                ToolbarView()
            }
            
            // Tab bar
            if appState.documents.count > 0 {
                TabBarView()
            }
            
            // Editor area
            Group {
                if let document = appState.activeDocument {
                    EditorContainerView(document: document)
                } else {
                    WelcomeView()
                }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }

            // Find/Replace bar
            if appState.showFindReplace {
                FindReplaceView()
            }
            
            // Status bar
            if settings.showStatusBar {
                StatusBarView()
            }
        }
        .background(settings.currentTheme.backgroundColor)
    }

    /// Open each dropped file URL as a new tab (existing tabs are reused
    /// by `AppState.openFile(at:)`).
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileURLType = UTType.fileURL.identifier
        var didAccept = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(fileURLType) {
            didAccept = true
            _ = provider.loadDataRepresentation(forTypeIdentifier: fileURLType) { data, _ in
                guard let data = data,
                      let url = URL(dataRepresentation: data, isAbsolute: true) else { return }
                DispatchQueue.main.async {
                    appState.openFile(at: url)
                }
            }
        }
        return didAccept
    }
}

/// Tab bar for open documents
struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.documents) { doc in
                    TabItemView(document: doc, isActive: doc.id == appState.activeDocument?.id)
                        .onTapGesture {
                            appState.setActiveDocument(doc)
                        }
                }
                Spacer()
            }
        }
        .frame(height: 32)
        .background(settings.currentTheme.gutterBackgroundColor)
    }
}

/// Individual tab item
struct TabItemView: View {
    @ObservedObject var document: Document
    let isActive: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        HStack(spacing: 4) {
            if document.isModified {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
            
            Text(document.name)
                .font(.system(size: 12))
                .lineLimit(1)
            
            Button(action: {
                appState.closeDocument(document)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(settings.currentTheme.textColor.opacity(0.5))
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isActive ?
                settings.currentTheme.backgroundColor :
                settings.currentTheme.gutterBackgroundColor
        )
        .foregroundColor(settings.currentTheme.textColor)
        .overlay(
            Rectangle()
                .frame(height: isActive ? 2 : 0)
                .foregroundColor(.accentColor),
            alignment: .bottom
        )
    }
}

/// Welcome view shown when no documents are open
struct WelcomeView: View {
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(settings.currentTheme.textColor.opacity(0.3))
            
            Text("WEditor")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(settings.currentTheme.textColor.opacity(0.6))
            
            Text("A powerful text editor for macOS")
                .font(.system(size: 16))
                .foregroundColor(settings.currentTheme.textColor.opacity(0.4))
            
            VStack(alignment: .leading, spacing: 8) {
                ShortcutHintView(shortcut: "⌘N", description: "New File")
                ShortcutHintView(shortcut: "⌘O", description: "Open File")
                ShortcutHintView(shortcut: "⌘⇧N", description: "New Window")
                ShortcutHintView(shortcut: "⌘L", description: "Column Edit Mode")
                ShortcutHintView(shortcut: "⌘F", description: "Find")
                ShortcutHintView(shortcut: "⌘⌥F", description: "Find & Replace")
                ShortcutHintView(shortcut: "Drop files", description: "Open in new tabs")
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.currentTheme.backgroundColor)
    }
}

/// Shortcut hint row
struct ShortcutHintView: View {
    let shortcut: String
    let description: String
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        HStack(spacing: 12) {
            Text(shortcut)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(settings.currentTheme.textColor.opacity(0.6))
                .frame(width: 60, alignment: .trailing)
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(settings.currentTheme.textColor.opacity(0.4))
        }
    }
}

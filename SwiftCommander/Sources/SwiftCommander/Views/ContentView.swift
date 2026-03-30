import SwiftUI

/// Main content view with dual panes
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HSplitView {
            // Quick Access sidebar
            if appState.showQuickAccess {
                QuickAccessView()
                    .frame(minWidth: 150, maxWidth: 200)
            }
            
            // Main dual pane area
            VStack(spacing: 0) {
                // Top toolbar
                ToolbarView()
                
                Divider()
                
                // Dual pane file browsers
                HSplitView {
                    FilePaneView(pane: appState.leftPane)
                        .onTapGesture {
                            appState.activePaneSide = .left
                        }
                    
                    FilePaneView(pane: appState.rightPane)
                        .onTapGesture {
                            appState.activePaneSide = .right
                        }
                }
                
                Divider()
                
                // Bottom function key bar
                FunctionKeyBar()
            }
            
            // Preview panel
            if appState.showPreviewPanel {
                PreviewPanelView()
                    .frame(minWidth: 200, maxWidth: 300)
            }
        }
        .onAppear {
            appState.loadPaneContents(appState.leftPane)
            appState.loadPaneContents(appState.rightPane)
        }
        .sheet(isPresented: $appState.showNewFolderDialog) {
            NewFolderDialog()
        }
        .sheet(isPresented: $appState.showNewFileDialog) {
            NewFileDialog()
        }
        .sheet(isPresented: $appState.showRenameDialog) {
            RenameDialog()
        }
        .sheet(isPresented: $appState.showSearchDialog) {
            SearchDialog()
        }
        .sheet(isPresented: $appState.showGoToPathDialog) {
            GoToPathDialog()
        }
        .sheet(isPresented: $appState.showArchiveDialog) {
            CreateArchiveDialog()
        }
        .confirmationDialog(
            "Delete Items?",
            isPresented: $appState.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                deleteSelectedItems(permanently: false)
            }
            Button("Delete Permanently", role: .destructive) {
                deleteSelectedItems(permanently: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = appState.activePane?.selectedItems.count ?? 0
            Text("Are you sure you want to delete \(count) item(s)?")
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") {
                appState.errorMessage = nil
            }
        } message: {
            if let error = appState.errorMessage {
                Text(error)
            }
        }
    }
    
    private func deleteSelectedItems(permanently: Bool) {
        guard let pane = appState.activePane else { return }
        let urls = pane.selectedFileItems.map { $0.url }
        
        do {
            try FileManagerService.shared.deleteItems(urls, permanently: permanently)
            appState.refreshActivePane()
        } catch {
            appState.showErrorMessage(error.localizedDescription)
        }
    }
}

/// Top toolbar with navigation and actions
struct ToolbarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Left pane path
            PathBar(pane: appState.leftPane)
            
            Spacer()
            
            // Center actions
            HStack(spacing: 8) {
                Button(action: { appState.showHiddenFiles.toggle() }) {
                    Image(systemName: appState.showHiddenFiles ? "eye.fill" : "eye.slash")
                }
                .buttonStyle(.borderless)
                .help("Toggle hidden files")
                
                Button(action: { appState.refreshBothPanes() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            
            Spacer()
            
            // Right pane path
            PathBar(pane: appState.rightPane)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// Path bar with navigation buttons
struct PathBar: View {
    @ObservedObject var pane: PaneState
    @EnvironmentObject var appState: AppState
    
    private var isActive: Bool {
        pane.side == appState.activePaneSide
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Navigation buttons
            Button(action: { pane.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(pane.historyBack.isEmpty)
            
            Button(action: { pane.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(pane.historyForward.isEmpty)
            
            Button(action: { pane.goUp() }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(pane.currentPath.path == "/")
            
            // Path display
            TextField("Path", text: .constant(pane.currentPath.path))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(minWidth: 200)
                .onSubmit {
                    let url = URL(fileURLWithPath: pane.currentPath.path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        pane.navigateTo(url)
                        appState.loadPaneContents(pane)
                    }
                }
        }
        .padding(4)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

/// Quick access sidebar
struct QuickAccessView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(QuickAccessCategory.allCases, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(appState.quickAccessItems.filter { $0.category == category }) { item in
                        QuickAccessRow(item: item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

/// Quick access item row
struct QuickAccessRow: View {
    let item: QuickAccessItem
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: {
            appState.navigateTo(item.url)
            appState.refreshActivePane()
        }) {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                Text(item.name)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Preview panel for selected file
struct PreviewPanelView: View {
    @EnvironmentObject var appState: AppState
    
    var selectedItem: FileItem? {
        appState.activePane?.selectedItem
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .padding(.horizontal)
            
            Divider()
            
            if let item = selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Icon and name
                        HStack(spacing: 12) {
                            Image(systemName: item.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                
                                Text(item.isDirectory ? "Folder" : item.fileExtension.uppercased())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // File info
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Size", value: item.formattedSize)
                            InfoRow(label: "Modified", value: item.formattedModificationDate)
                            InfoRow(label: "Permissions", value: item.permissions)
                            InfoRow(label: "Owner", value: item.owner)
                            InfoRow(label: "Path", value: item.url.path)
                        }
                        .padding(.horizontal)
                        
                        // Preview content for text files
                        if !item.isDirectory && isTextFile(item) {
                            Divider()
                            
                            TextPreview(url: item.url)
                                .padding(.horizontal)
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("No selection")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical)
        .frame(maxHeight: .infinity)
    }
    
    /// File extensions recognized as text files
    private static let textFileExtensions: Set<String> = [
        "txt", "md", "swift", "py", "js", "ts", "json", "xml", "html", "css", 
        "sh", "c", "cpp", "h", "java", "go", "rs", "rb", "yml", "yaml", 
        "toml", "ini", "cfg", "conf", "log"
    ]
    
    private func isTextFile(_ item: FileItem) -> Bool {
        Self.textFileExtensions.contains(item.fileExtension)
    }
}

/// Info row for preview panel
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            Text(value)
                .textSelection(.enabled)
        }
        .font(.system(size: 11))
    }
}

/// Text file preview
struct TextPreview: View {
    let url: URL
    @State private var content: String = ""
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Content Preview")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                Text(content)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxHeight: 200)
            }
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: url) { _, _ in
            loadContent()
        }
    }
    
    private func loadContent() {
        do {
            let data = try Data(contentsOf: url)
            if data.count > 10000 {
                content = (String(data: data.prefix(10000), encoding: .utf8) ?? "") + "\n... (truncated)"
            } else {
                content = String(data: data, encoding: .utf8) ?? "Unable to read file"
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
            content = ""
        }
    }
}

/// Bottom function key bar (F1-F10)
struct FunctionKeyBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 2) {
            FunctionButton(key: "F1", label: "Help", action: showHelp)
            FunctionButton(key: "F2", label: "Rename", action: {
                if appState.activePane?.selectedItem != nil {
                    appState.showRenameDialog = true
                }
            })
            FunctionButton(key: "F3", label: "View", action: viewFile)
            FunctionButton(key: "F4", label: "Edit", action: editFile)
            FunctionButton(key: "F5", label: "Copy", action: { appState.showCopyDialog = true })
            FunctionButton(key: "F6", label: "Move", action: { appState.showMoveDialog = true })
            FunctionButton(key: "F7", label: "Mkdir", action: { appState.showNewFolderDialog = true })
            FunctionButton(key: "F8", label: "Delete", action: {
                if !(appState.activePane?.selectedItems.isEmpty ?? true) {
                    appState.showDeleteConfirmation = true
                }
            })
            FunctionButton(key: "F9", label: "Terminal", action: {
                if let path = appState.activePane?.currentPath {
                    TerminalManager.shared.openTerminal(at: path)
                }
            })
            FunctionButton(key: "F10", label: "Quit", action: {
                NSApplication.shared.terminate(nil)
            })
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func showHelp() {
        // Show help window or documentation
    }
    
    private func viewFile() {
        guard let item = appState.activePane?.selectedItem else { return }
        TerminalManager.shared.openFile(item.url)
    }
    
    private func editFile() {
        guard let item = appState.activePane?.selectedItem else { return }
        // Open with default text editor
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        TerminalManager.shared.openFile(item.url, withApp: textEdit)
    }
}

/// Single function key button
struct FunctionButton: View {
    let key: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(key)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
    }
}

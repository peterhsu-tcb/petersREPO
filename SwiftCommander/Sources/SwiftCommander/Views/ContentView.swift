import SwiftUI

/// Main content view with dual-pane file browser
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView()
            
            Divider()
            
            // Main content - dual pane
            HStack(spacing: 0) {
                // Left panel
                FileListView(panelState: appState.leftPanel, side: .left)
                    .border(appState.activePanel == .left ? Color.accentColor : Color.clear, width: 2)
                    .onTapGesture {
                        appState.focusPanel(.left)
                    }
                
                Divider()
                
                // Right panel
                FileListView(panelState: appState.rightPanel, side: .right)
                    .border(appState.activePanel == .right ? Color.accentColor : Color.clear, width: 2)
                    .onTapGesture {
                        appState.focusPanel(.right)
                    }
            }
            
            Divider()
            
            // Function key bar
            FunctionKeyBar()
            
            // Status bar
            StatusBarView()
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $appState.showGoToDialog) {
            GoToDirectoryView()
        }
        .sheet(isPresented: $appState.showNewFolderDialog) {
            NewFolderView()
        }
        .sheet(isPresented: $appState.showFindDialog) {
            FindFilesView()
        }
        .sheet(isPresented: $appState.showCopyDialog) {
            CopyMoveDialogView(operation: .copy)
        }
        .sheet(isPresented: $appState.showMoveDialog) {
            CopyMoveDialogView(operation: .move)
        }
        .sheet(isPresented: $appState.showDeleteConfirmation) {
            DeleteConfirmationView()
        }
        .sheet(isPresented: $appState.showCompareView) {
            CompareView()
        }
        .overlay {
            if appState.isProcessing {
                ProcessingOverlayView(message: appState.processingMessage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
            // Refresh panels when app becomes active
            appState.refreshPanels()
        }
    }
}

// MARK: - Status Bar View

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            // Left panel info
            Text(appState.leftPanel.directoryInfo)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Clipboard info
            if !appState.clipboard.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: appState.clipboardOperation == .copy ? "doc.on.doc" : "scissors")
                        .font(.caption)
                    Text("\(appState.clipboard.count) items in clipboard")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Right panel info
            Text(appState.rightPanel.directoryInfo)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Processing Overlay

struct ProcessingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(message)
                    .font(.headline)
            }
            .padding(32)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

// MARK: - Go To Directory View

struct GoToDirectoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var path: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Directory")
                .font(.headline)
            
            TextField("Enter path...", text: $path)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
                .onSubmit {
                    goToPath()
                }
            
            // Recent directories
            if !appState.recentDirectories.directories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.recentDirectories.directories.prefix(10), id: \.self) { url in
                                Button {
                                    path = url.path
                                } label: {
                                    HStack {
                                        Image(systemName: "folder")
                                        Text(url.path)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .frame(width: 400)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Go") {
                    goToPath()
                }
                .keyboardShortcut(.return)
                .disabled(path.isEmpty)
            }
        }
        .padding(24)
        .onAppear {
            path = appState.activePanelState.currentDirectory.path
        }
    }
    
    private func goToPath() {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            appState.navigateTo(url)
            dismiss()
        } else {
            appState.errorMessage = "Path does not exist: \(path)"
            appState.showError = true
        }
    }
}

// MARK: - New Folder View

struct NewFolderView: View {
    @EnvironmentObject var appState: AppState
    @State private var folderName: String = "New Folder"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Folder")
                .font(.headline)
            
            TextField("Folder name", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    createFolder()
                }
            
            Text("in \(appState.activePanelState.currentDirectory.path)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    createFolder()
                }
                .keyboardShortcut(.return)
                .disabled(folderName.isEmpty || !folderName.isValidFilename)
            }
        }
        .padding(24)
    }
    
    private func createFolder() {
        appState.createDirectory(named: folderName)
        dismiss()
    }
}

// MARK: - Find Files View

struct FindFilesView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchPattern: String = ""
    @State private var searchInSubdirectories: Bool = true
    @State private var caseSensitive: Bool = false
    @State private var searchResults: [FileItem] = []
    @State private var isSearching: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Find Files")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Search pattern (e.g., *.txt)", text: $searchPattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 400)
                
                Toggle("Search in subdirectories", isOn: $searchInSubdirectories)
                Toggle("Case sensitive", isOn: $caseSensitive)
            }
            
            Text("Searching in: \(appState.activePanelState.currentDirectory.path)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isSearching {
                ProgressView("Searching...")
            } else if !searchResults.isEmpty {
                VStack(alignment: .leading) {
                    Text("Results: \(searchResults.count) files found")
                        .font(.caption)
                    
                    List(searchResults) { item in
                        HStack {
                            Image(systemName: item.iconName)
                                .foregroundColor(Color.forFileType(item.fileType))
                            Text(item.url.path)
                                .lineLimit(1)
                        }
                        .onTapGesture(count: 2) {
                            appState.navigateTo(item.url.deletingLastPathComponent())
                            dismiss()
                        }
                    }
                    .frame(height: 200)
                }
            }
            
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Search") {
                    performSearch()
                }
                .keyboardShortcut(.return)
                .disabled(searchPattern.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    private func performSearch() {
        isSearching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let criteria = SearchService.SearchCriteria(
                namePattern: searchPattern,
                searchInSubdirectories: searchInSubdirectories,
                caseSensitive: caseSensitive
            )
            
            let result = appState.searchService.search(
                in: appState.activePanelState.currentDirectory,
                criteria: criteria
            )
            
            DispatchQueue.main.async {
                searchResults = result.items
                isSearching = false
            }
        }
    }
}

// MARK: - Copy/Move Dialog View

struct CopyMoveDialogView: View {
    @EnvironmentObject var appState: AppState
    let operation: CopyMoveOperation
    @Environment(\.dismiss) private var dismiss
    
    enum CopyMoveOperation {
        case copy
        case move
        
        var title: String {
            switch self {
            case .copy: return "Copy"
            case .move: return "Move"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("\(operation.title) Files")
                .font(.headline)
            
            let selectedCount = appState.activePanelState.selectedFiles.count
            Text("\(selectedCount) item(s) selected")
            
            Text("From: \(appState.activePanelState.currentDirectory.path)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("To: \(appState.inactivePanelState.currentDirectory.path)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button(operation.title) {
                    if operation == .copy {
                        appState.copyToOtherPanel()
                    } else {
                        appState.moveToOtherPanel()
                    }
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
    }
}

// MARK: - Delete Confirmation View

struct DeleteConfirmationView: View {
    @EnvironmentObject var appState: AppState
    @State private var moveToTrash: Bool = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Delete Files")
                .font(.headline)
            
            let selectedCount = appState.activePanelState.selectedFiles.count
            Text("Are you sure you want to delete \(selectedCount) item(s)?")
            
            Toggle("Move to Trash", isOn: $moveToTrash)
            
            if !moveToTrash {
                Text("⚠️ Files will be permanently deleted!")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Delete") {
                    appState.deleteSelectedFiles(moveToTrash: moveToTrash)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1200, height: 800)
}

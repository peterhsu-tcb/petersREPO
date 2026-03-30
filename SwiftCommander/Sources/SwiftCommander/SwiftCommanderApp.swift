import SwiftUI

/// Main application entry point
@main
struct SwiftCommanderApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.automatic)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    createNewWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("New Folder") {
                    appState.showNewFolderDialog = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("New File") {
                    appState.showNewFileDialog = true
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            
            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("Select All") {
                    appState.activePane?.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)
                
                Button("Invert Selection") {
                    appState.invertSelection()
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            
            // View menu
            CommandMenu("View") {
                Toggle("Show Hidden Files", isOn: $appState.showHiddenFiles)
                    .keyboardShortcut(".", modifiers: [.command, .shift])
                
                Toggle("Show Preview Panel", isOn: $appState.showPreviewPanel)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Toggle("Show Quick Access", isOn: $appState.showQuickAccess)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Refresh") {
                    appState.refreshActivePane()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Menu("Sort By") {
                    ForEach(SortColumn.allCases, id: \.self) { column in
                        Button(column.rawValue) {
                            appState.activePane?.sortColumn = column
                            appState.activePane?.sort()
                        }
                    }
                    
                    Divider()
                    
                    Toggle("Ascending", isOn: Binding(
                        get: { appState.activePane?.sortAscending ?? true },
                        set: { appState.activePane?.sortAscending = $0 }
                    ))
                }
            }
            
            // Go menu
            CommandMenu("Go") {
                Button("Back") {
                    appState.activePane?.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(appState.activePane?.historyBack.isEmpty ?? true)
                
                Button("Forward") {
                    appState.activePane?.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(appState.activePane?.historyForward.isEmpty ?? true)
                
                Button("Enclosing Folder") {
                    appState.activePane?.goUp()
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                
                Divider()
                
                Button("Home") {
                    appState.navigateTo(FileManager.default.homeDirectoryForCurrentUser)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                
                Button("Desktop") {
                    let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
                    appState.navigateTo(desktop)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Button("Documents") {
                    let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
                    appState.navigateTo(docs)
                }
                
                Button("Downloads") {
                    let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
                    appState.navigateTo(downloads)
                }
                
                Divider()
                
                Button("Go to Path...") {
                    appState.showGoToPathDialog = true
                }
                .keyboardShortcut("g", modifiers: .command)
            }
            
            // Tools menu
            CommandMenu("Tools") {
                Button("Open Terminal Here") {
                    if let path = appState.activePane?.currentPath {
                        TerminalManager.shared.openTerminal(at: path)
                    }
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Search...") {
                    appState.showSearchDialog = true
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Divider()
                
                Button("Create Archive...") {
                    appState.showArchiveDialog = true
                }
                .disabled(appState.activePane?.selectedItems.isEmpty ?? true)
                
                Button("Extract Archive...") {
                    appState.extractSelectedArchive()
                }
                .disabled(!appState.canExtractSelected)
                
                Divider()
                
                Button("Compare Files") {
                    appState.compareSelected()
                }
                .disabled(!appState.canCompare)
            }
            
            // Window menu additions
            CommandGroup(before: .windowList) {
                Button("Switch Panes") {
                    appState.switchPane()
                }
                .keyboardShortcut(.tab, modifiers: [])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    private func createNewWindow() {
        if let window = NSApplication.shared.windows.first {
            let newWindow = NSWindow(
                contentRect: window.frame.offsetBy(dx: 30, dy: -30),
                styleMask: window.styleMask,
                backing: .buffered,
                defer: false
            )
            newWindow.title = "SwiftCommander"
            let newAppState = AppState()
            newWindow.contentView = NSHostingView(rootView: ContentView().environmentObject(newAppState))
            newWindow.makeKeyAndOrderFront(nil)
        }
    }
}

/// Main application state
class AppState: ObservableObject {
    @Published var leftPane: PaneState
    @Published var rightPane: PaneState
    @Published var activePaneSide: PaneSide = .left
    
    // UI state
    @Published var showHiddenFiles: Bool = false
    @Published var showPreviewPanel: Bool = true
    @Published var showQuickAccess: Bool = true
    
    // Dialog states
    @Published var showNewFolderDialog = false
    @Published var showNewFileDialog = false
    @Published var showRenameDialog = false
    @Published var showDeleteConfirmation = false
    @Published var showCopyDialog = false
    @Published var showMoveDialog = false
    @Published var showSearchDialog = false
    @Published var showArchiveDialog = false
    @Published var showGoToPathDialog = false
    @Published var showConflictDialog = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Quick access items
    @Published var quickAccessItems: [QuickAccessItem] = []
    
    // Clipboard
    @Published var clipboard: [URL] = []
    @Published var clipboardIsCut = false
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.leftPane = PaneState(side: .left, initialPath: home)
        self.rightPane = PaneState(side: .right, initialPath: home)
        
        setupQuickAccess()
    }
    
    /// Get the active pane
    var activePane: PaneState? {
        activePaneSide == .left ? leftPane : rightPane
    }
    
    /// Get the inactive pane
    var inactivePane: PaneState? {
        activePaneSide == .left ? rightPane : leftPane
    }
    
    /// Switch active pane
    func switchPane() {
        activePaneSide = activePaneSide == .left ? .right : .left
    }
    
    /// Navigate to a path in the active pane
    func navigateTo(_ url: URL) {
        activePane?.navigateTo(url)
    }
    
    /// Refresh the active pane
    func refreshActivePane() {
        loadPaneContents(activePane)
    }
    
    /// Refresh both panes
    func refreshBothPanes() {
        loadPaneContents(leftPane)
        loadPaneContents(rightPane)
    }
    
    /// Load contents for a pane
    func loadPaneContents(_ pane: PaneState?) {
        guard let pane = pane else { return }
        
        pane.isLoading = true
        pane.errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let items = try FileManagerService.shared.listDirectory(
                    at: pane.currentPath,
                    showHidden: self.showHiddenFiles || pane.showHiddenFiles
                )
                
                DispatchQueue.main.async {
                    pane.items = items
                    pane.sort()
                    pane.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    pane.errorMessage = error.localizedDescription
                    pane.isLoading = false
                }
            }
        }
    }
    
    /// Setup quick access items
    func setupQuickAccess() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        
        var items: [QuickAccessItem] = []
        
        // Favorites
        let favorites: [(String, String, String)] = [
            ("Home", home.path, "house.fill"),
            ("Desktop", home.appendingPathComponent("Desktop").path, "menubar.dock.rectangle"),
            ("Documents", home.appendingPathComponent("Documents").path, "doc.fill"),
            ("Downloads", home.appendingPathComponent("Downloads").path, "arrow.down.circle.fill"),
            ("Applications", "/Applications", "app.fill")
        ]
        
        for (name, path, icon) in favorites {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: path) {
                items.append(QuickAccessItem(name: name, url: url, icon: icon, category: .favorites))
            }
        }
        
        // Devices/Volumes
        if let volumes = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil) {
            for volume in volumes {
                items.append(QuickAccessItem(name: volume.lastPathComponent, url: volume, icon: "externaldrive.fill", category: .devices))
            }
        }
        
        quickAccessItems = items
    }
    
    /// Invert selection in active pane
    func invertSelection() {
        guard let pane = activePane else { return }
        let allIds = Set(pane.items.filter { $0.name != ".." }.map { $0.id })
        pane.selectedItems = allIds.subtracting(pane.selectedItems)
    }
    
    /// Check if selected item is an extractable archive
    var canExtractSelected: Bool {
        guard let pane = activePane,
              let item = pane.selectedItem else { return false }
        return ArchiveManager.shared.isArchive(item.url)
    }
    
    /// Check if we can compare selected items
    var canCompare: Bool {
        // Need exactly 2 items selected or 1 item in each pane
        if let pane = activePane, pane.selectedItems.count == 2 {
            let items = pane.selectedFileItems
            return items.allSatisfy { !$0.isDirectory }
        }
        return false
    }
    
    /// Extract selected archive
    func extractSelectedArchive() {
        guard let pane = activePane,
              let item = pane.selectedItem,
              ArchiveManager.shared.isArchive(item.url) else { return }
        
        Task {
            do {
                try await ArchiveManager.shared.extractArchive(from: item.url, to: pane.currentPath)
                await MainActor.run {
                    refreshActivePane()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    /// Compare selected files
    func compareSelected() {
        // This would integrate with SwiftCompare functionality
    }
    
    /// Copy selected items to clipboard
    func copyToClipboard() {
        guard let pane = activePane else { return }
        clipboard = pane.selectedFileItems.map { $0.url }
        clipboardIsCut = false
    }
    
    /// Cut selected items to clipboard
    func cutToClipboard() {
        guard let pane = activePane else { return }
        clipboard = pane.selectedFileItems.map { $0.url }
        clipboardIsCut = true
    }
    
    /// Paste from clipboard
    func pasteFromClipboard() {
        guard let pane = activePane, !clipboard.isEmpty else { return }
        
        Task {
            do {
                if clipboardIsCut {
                    try await FileManagerService.shared.moveItems(clipboard, to: pane.currentPath) { _ in
                        return .replace
                    }
                    await MainActor.run {
                        clipboard = []
                        clipboardIsCut = false
                    }
                } else {
                    try await FileManagerService.shared.copyItems(clipboard, to: pane.currentPath) { _ in
                        return .replace
                    }
                }
                
                await MainActor.run {
                    refreshBothPanes()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    /// Show error message
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

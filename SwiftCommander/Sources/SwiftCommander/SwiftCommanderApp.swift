import SwiftUI

@main
struct SwiftCommanderApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // File Menu
            CommandGroup(after: .newItem) {
                Button("New Folder") {
                    appState.createNewDirectory()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("Refresh") {
                    appState.refreshPanels()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            
            // Edit Menu
            CommandGroup(after: .pasteboard) {
                Button("Select All") {
                    appState.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)
                
                Button("Invert Selection") {
                    appState.invertSelection()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            
            // View Menu
            CommandGroup(after: .sidebar) {
                Button("Toggle Hidden Files") {
                    appState.toggleHiddenFiles()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Focus Left Panel") {
                    appState.focusPanel(.left)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Focus Right Panel") {
                    appState.focusPanel(.right)
                }
                .keyboardShortcut("2", modifiers: .command)
            }
            
            // Go Menu
            CommandGroup(replacing: .help) {
                Button("Go to Directory...") {
                    appState.showGoToDialog = true
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Divider()
                
                Button("Back") {
                    appState.navigateBack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button("Forward") {
                    appState.navigateForward()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Button("Up") {
                    appState.navigateUp()
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                
                Divider()
                
                Button("Home") {
                    appState.navigateToHome()
                }
                .keyboardShortcut("h", modifiers: .command)
            }
            
            // Tools Menu
            CommandMenu("Tools") {
                Button("Find Files...") {
                    appState.showFindDialog = true
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Divider()
                
                Button("Open Terminal Here") {
                    appState.openTerminal()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    // Panel states
    @Published var leftPanel: PanelState
    @Published var rightPanel: PanelState
    @Published var activePanel: PanelSide = .left
    
    // Services
    let fileOperationsService = FileOperationsService()
    let navigationService = NavigationService()
    let searchService = SearchService()
    let archiveService = ArchiveService()
    
    // Bookmarks
    @Published var bookmarkManager = BookmarkManager()
    @Published var recentDirectories = RecentDirectories()
    
    // Dialog states
    @Published var showGoToDialog = false
    @Published var showFindDialog = false
    @Published var showNewFolderDialog = false
    @Published var showRenameDialog = false
    @Published var showDeleteConfirmation = false
    @Published var showCopyDialog = false
    @Published var showMoveDialog = false
    @Published var showPropertiesDialog = false
    
    // Operation state
    @Published var isProcessing = false
    @Published var processingMessage = ""
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Clipboard
    @Published var clipboard: [URL] = []
    @Published var clipboardOperation: ClipboardOperation = .none
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.leftPanel = PanelState(side: .left, initialDirectory: homeDir)
        self.rightPanel = PanelState(side: .right, initialDirectory: homeDir)
        
        // Load initial contents
        refreshPanel(.left)
        refreshPanel(.right)
    }
    
    // MARK: - Active Panel
    
    var activePanelState: PanelState {
        activePanel == .left ? leftPanel : rightPanel
    }
    
    var inactivePanelState: PanelState {
        activePanel == .left ? rightPanel : leftPanel
    }
    
    func focusPanel(_ side: PanelSide) {
        activePanel = side
    }
    
    func toggleActivePanel() {
        activePanel = activePanel.opposite
    }
    
    // MARK: - Navigation
    
    func navigateTo(_ url: URL, panel: PanelSide? = nil) {
        let targetPanel = panel ?? activePanel
        let panelState = targetPanel == .left ? leftPanel : rightPanel
        
        panelState.navigateTo(url)
        recentDirectories.addRecent(url)
        refreshPanel(targetPanel)
    }
    
    func navigateBack() {
        activePanelState.navigateBack()
        refreshPanel(activePanel)
    }
    
    func navigateForward() {
        activePanelState.navigateForward()
        refreshPanel(activePanel)
    }
    
    func navigateUp() {
        activePanelState.navigateToParent()
        refreshPanel(activePanel)
    }
    
    func navigateToHome() {
        navigateTo(FileManager.default.homeDirectoryForCurrentUser)
    }
    
    // MARK: - Panel Refresh
    
    func refreshPanel(_ side: PanelSide) {
        let panelState = side == .left ? leftPanel : rightPanel
        
        panelState.isLoading = true
        panelState.errorMessage = nil
        
        do {
            let files = try fileOperationsService.listDirectory(at: panelState.currentDirectory)
            panelState.files = files
        } catch {
            panelState.errorMessage = error.localizedDescription
            panelState.files = []
        }
        
        panelState.isLoading = false
    }
    
    func refreshPanels() {
        refreshPanel(.left)
        refreshPanel(.right)
    }
    
    // MARK: - Selection
    
    func selectAll() {
        activePanelState.selectAll()
    }
    
    func clearSelection() {
        activePanelState.clearSelection()
    }
    
    func invertSelection() {
        let currentSelection = activePanelState.selectedFiles
        let allFiles = Set(activePanelState.filteredFiles.map { $0.id })
        activePanelState.selectedFiles = allFiles.subtracting(currentSelection)
    }
    
    // MARK: - File Operations
    
    func copySelectedFiles() {
        let selectedItems = activePanelState.selectedFileItems
        clipboard = selectedItems.map { $0.url }
        clipboardOperation = .copy
    }
    
    func cutSelectedFiles() {
        let selectedItems = activePanelState.selectedFileItems
        clipboard = selectedItems.map { $0.url }
        clipboardOperation = .cut
    }
    
    func pasteFiles() {
        guard !clipboard.isEmpty else { return }
        
        let destination = activePanelState.currentDirectory
        
        isProcessing = true
        processingMessage = clipboardOperation == .copy ? "Copying files..." : "Moving files..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                if self.clipboardOperation == .copy {
                    _ = try self.fileOperationsService.copyMultiple(sources: self.clipboard, to: destination)
                } else {
                    _ = try self.fileOperationsService.moveMultiple(sources: self.clipboard, to: destination)
                    self.clipboard.removeAll()
                    self.clipboardOperation = .none
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.refreshPanels()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    func deleteSelectedFiles(moveToTrash: Bool = true) {
        let selectedItems = activePanelState.selectedFileItems
        guard !selectedItems.isEmpty else { return }
        
        isProcessing = true
        processingMessage = "Deleting files..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let urls = selectedItems.map { $0.url }
                _ = try self.fileOperationsService.deleteMultiple(urls: urls, moveToTrash: moveToTrash)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.activePanelState.clearSelection()
                    self.refreshPanels()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    func createNewDirectory() {
        showNewFolderDialog = true
    }
    
    func createDirectory(named name: String) {
        do {
            _ = try fileOperationsService.createDirectory(at: activePanelState.currentDirectory, named: name)
            refreshPanel(activePanel)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func renameFile(_ file: FileItem, to newName: String) {
        do {
            _ = try fileOperationsService.rename(at: file.url, to: newName)
            refreshPanel(activePanel)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - View Toggle
    
    func toggleHiddenFiles() {
        activePanelState.showHiddenFiles.toggle()
    }
    
    // MARK: - External Operations
    
    func openFile(_ file: FileItem) {
        if file.isDirectory {
            navigateTo(file.url)
        } else {
            navigationService.openFile(at: file.url)
        }
    }
    
    func openInEditor(_ file: FileItem) {
        navigationService.openInTextEditor(at: file.url)
    }
    
    func revealInFinder(_ file: FileItem) {
        navigationService.revealInFinder(at: file.url)
    }
    
    func openTerminal() {
        navigationService.openTerminal(at: activePanelState.currentDirectory)
    }
    
    // MARK: - F-Key Commands
    
    func executeCommand(_ action: CommandAction) {
        switch action {
        case .help:
            // Show help
            break
        case .refresh:
            refreshPanels()
        case .view:
            if let file = activePanelState.selectedFileItems.first {
                openFile(file)
            }
        case .edit:
            if let file = activePanelState.selectedFileItems.first {
                openInEditor(file)
            }
        case .copy:
            showCopyDialog = true
        case .move:
            showMoveDialog = true
        case .newDirectory:
            showNewFolderDialog = true
        case .delete:
            showDeleteConfirmation = true
        case .menu:
            // Show context menu
            break
        case .quit:
            NSApplication.shared.terminate(nil)
        case .goToDirectory:
            showGoToDialog = true
        case .search:
            showFindDialog = true
        case .selectAll:
            selectAll()
        case .toggleHidden:
            toggleHiddenFiles()
        case .focusLeftPanel:
            focusPanel(.left)
        case .focusRightPanel:
            focusPanel(.right)
        case .openFile:
            if let file = activePanelState.selectedFileItems.first {
                openFile(file)
            }
        case .rename:
            showRenameDialog = true
        case .properties:
            showPropertiesDialog = true
        case .bookmark:
            bookmarkManager.addBookmark(url: activePanelState.currentDirectory)
        case .terminal:
            openTerminal()
        }
    }
    
    // MARK: - Copy/Move to Other Panel
    
    func copyToOtherPanel() {
        let selectedItems = activePanelState.selectedFileItems
        guard !selectedItems.isEmpty else { return }
        
        let destination = inactivePanelState.currentDirectory
        
        isProcessing = true
        processingMessage = "Copying files..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let urls = selectedItems.map { $0.url }
                _ = try self.fileOperationsService.copyMultiple(sources: urls, to: destination)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.refreshPanels()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    func moveToOtherPanel() {
        let selectedItems = activePanelState.selectedFileItems
        guard !selectedItems.isEmpty else { return }
        
        let destination = inactivePanelState.currentDirectory
        
        isProcessing = true
        processingMessage = "Moving files..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let urls = selectedItems.map { $0.url }
                _ = try self.fileOperationsService.moveMultiple(sources: urls, to: destination)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.activePanelState.clearSelection()
                    self.refreshPanels()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Clipboard Operation

enum ClipboardOperation {
    case none
    case copy
    case cut
}

import Foundation

/// Represents the state of a file panel (left or right)
class PanelState: ObservableObject, Identifiable {
    let id: UUID
    let side: PanelSide
    
    @Published var currentDirectory: URL
    @Published var files: [FileItem]
    @Published var selectedFiles: Set<UUID>
    @Published var focusedFile: UUID?
    @Published var sortOrder: SortOrder
    @Published var showHiddenFiles: Bool
    @Published var filterText: String
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    
    /// Navigation history
    @Published var navigationHistory: [URL]
    @Published var historyIndex: Int
    
    /// Computed properties
    var canNavigateBack: Bool {
        historyIndex > 0
    }
    
    var canNavigateForward: Bool {
        historyIndex < navigationHistory.count - 1
    }
    
    var selectedFileItems: [FileItem] {
        files.filter { selectedFiles.contains($0.id) }
    }
    
    var filteredFiles: [FileItem] {
        var result = files
        
        // Apply hidden files filter
        if !showHiddenFiles {
            result = result.filter { !$0.isHidden }
        }
        
        // Apply text filter
        if !filterText.isEmpty {
            result = result.filter { 
                $0.name.localizedCaseInsensitiveContains(filterText) 
            }
        }
        
        // Apply sorting (directories first, then by sort order)
        result = result.sorted { first, second in
            // Directories always come first
            if first.isDirectory && !second.isDirectory {
                return true
            }
            if !first.isDirectory && second.isDirectory {
                return false
            }
            return sortOrder.comparator(first, second)
        }
        
        return result
    }
    
    var directoryInfo: String {
        let totalFiles = files.filter { !$0.isDirectory }.count
        let totalDirs = files.filter { $0.isDirectory }.count
        let selectedCount = selectedFiles.count
        
        if selectedCount > 0 {
            let selectedSize = selectedFileItems.reduce(0) { $0 + $1.size }
            return "\(selectedCount) selected (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))"
        }
        
        return "\(totalFiles) files, \(totalDirs) folders"
    }
    
    init(side: PanelSide, initialDirectory: URL? = nil) {
        self.id = UUID()
        self.side = side
        self.currentDirectory = initialDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        self.files = []
        self.selectedFiles = []
        self.focusedFile = nil
        self.sortOrder = .nameAscending
        self.showHiddenFiles = false
        self.filterText = ""
        self.isLoading = false
        self.errorMessage = nil
        self.navigationHistory = [self.currentDirectory]
        self.historyIndex = 0
    }
    
    /// Navigate to a directory
    func navigateTo(_ url: URL) {
        // Remove any forward history
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((historyIndex + 1)...)
        }
        
        // Add to history
        navigationHistory.append(url)
        historyIndex = navigationHistory.count - 1
        currentDirectory = url
        
        // Clear selection
        selectedFiles.removeAll()
        focusedFile = nil
    }
    
    /// Navigate back in history
    func navigateBack() {
        guard canNavigateBack else { return }
        historyIndex -= 1
        currentDirectory = navigationHistory[historyIndex]
        selectedFiles.removeAll()
        focusedFile = nil
    }
    
    /// Navigate forward in history
    func navigateForward() {
        guard canNavigateForward else { return }
        historyIndex += 1
        currentDirectory = navigationHistory[historyIndex]
        selectedFiles.removeAll()
        focusedFile = nil
    }
    
    /// Navigate to parent directory
    func navigateToParent() {
        let parentURL = currentDirectory.deletingLastPathComponent()
        if parentURL != currentDirectory {
            navigateTo(parentURL)
        }
    }
    
    /// Toggle selection for a file
    func toggleSelection(_ fileId: UUID) {
        if selectedFiles.contains(fileId) {
            selectedFiles.remove(fileId)
        } else {
            selectedFiles.insert(fileId)
        }
    }
    
    /// Select a single file (clearing other selections)
    func selectSingle(_ fileId: UUID) {
        selectedFiles = [fileId]
        focusedFile = fileId
    }
    
    /// Add file to selection
    func addToSelection(_ fileId: UUID) {
        selectedFiles.insert(fileId)
        focusedFile = fileId
    }
    
    /// Select all files
    func selectAll() {
        selectedFiles = Set(filteredFiles.map { $0.id })
    }
    
    /// Clear all selections
    func clearSelection() {
        selectedFiles.removeAll()
    }
    
    /// Select range of files
    func selectRange(from startId: UUID, to endId: UUID) {
        guard let startIndex = filteredFiles.firstIndex(where: { $0.id == startId }),
              let endIndex = filteredFiles.firstIndex(where: { $0.id == endId }) else {
            return
        }
        
        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        for index in range {
            selectedFiles.insert(filteredFiles[index].id)
        }
    }
}

/// Identifies which panel (left or right)
enum PanelSide: String, CaseIterable {
    case left
    case right
    
    var opposite: PanelSide {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }
}

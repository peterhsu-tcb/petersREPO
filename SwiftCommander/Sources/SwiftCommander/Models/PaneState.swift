import Foundation

/// Represents a pane in the dual-pane view
enum PaneSide: Equatable {
    case left
    case right
}

/// State for a single file browser pane
class PaneState: ObservableObject, Identifiable {
    let id = UUID()
    let side: PaneSide
    
    @Published var currentPath: URL
    @Published var items: [FileItem] = []
    @Published var selectedItems: Set<UUID> = []
    @Published var sortColumn: SortColumn = .name
    @Published var sortAscending: Bool = true
    @Published var showHiddenFiles: Bool = false
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    /// Navigation history
    @Published var historyBack: [URL] = []
    @Published var historyForward: [URL] = []
    
    init(side: PaneSide, path: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.side = side
        self.currentPath = path
    }
    
    /// Currently selected single item
    var selectedItem: FileItem? {
        guard selectedItems.count == 1,
              let selectedId = selectedItems.first else {
            return nil
        }
        return items.first { $0.id == selectedId }
    }
    
    /// All selected file items
    var selectedFileItems: [FileItem] {
        items.filter { selectedItems.contains($0.id) }
    }
    
    /// Filtered items based on search text
    var filteredItems: [FileItem] {
        guard !searchText.isEmpty else {
            return items
        }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// Navigate to a new path
    func navigateTo(_ url: URL, addToHistory: Bool = true) {
        if addToHistory && currentPath != url {
            historyBack.append(currentPath)
            historyForward.removeAll()
        }
        currentPath = url
        selectedItems.removeAll()
        searchText = ""
    }
    
    /// Go back in history
    func goBack() {
        guard let previousPath = historyBack.popLast() else { return }
        historyForward.append(currentPath)
        currentPath = previousPath
        selectedItems.removeAll()
    }
    
    /// Go forward in history
    func goForward() {
        guard let nextPath = historyForward.popLast() else { return }
        historyBack.append(currentPath)
        currentPath = nextPath
        selectedItems.removeAll()
    }
    
    /// Go to parent directory
    func goUp() {
        let parent = currentPath.deletingLastPathComponent()
        if parent != currentPath {
            navigateTo(parent)
        }
    }
    
    /// Select all items
    func selectAll() {
        selectedItems = Set(items.filter { $0.name != ".." }.map { $0.id })
    }
    
    /// Clear selection
    func clearSelection() {
        selectedItems.removeAll()
    }
    
    /// Toggle selection of an item
    func toggleSelection(_ item: FileItem) {
        if item.name == ".." { return }
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    /// Select single item (clear others)
    func selectSingle(_ item: FileItem) {
        if item.name == ".." {
            selectedItems.removeAll()
            return
        }
        selectedItems = [item.id]
    }
    
    /// Sort the items
    func sort() {
        items.sort { lhs, rhs in
            // Parent directory always first
            if lhs.name == ".." { return true }
            if rhs.name == ".." { return false }
            
            // Directories first
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            
            let comparison: ComparisonResult
            switch sortColumn {
            case .name:
                comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            case .size:
                comparison = lhs.size < rhs.size ? .orderedAscending : (lhs.size > rhs.size ? .orderedDescending : .orderedSame)
            case .date:
                let lhsDate = lhs.modificationDate ?? Date.distantPast
                let rhsDate = rhs.modificationDate ?? Date.distantPast
                comparison = lhsDate < rhsDate ? .orderedAscending : (lhsDate > rhsDate ? .orderedDescending : .orderedSame)
            case .type:
                comparison = lhs.fileExtension.localizedCaseInsensitiveCompare(rhs.fileExtension)
            }
            
            return sortAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }
}

/// Sort column options
enum SortColumn: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case date = "Date"
    case type = "Type"
}

/// Quick access item (favorites, drives, etc.)
struct QuickAccessItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let icon: String
    let category: QuickAccessCategory
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: QuickAccessItem, rhs: QuickAccessItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Categories for quick access items
enum QuickAccessCategory: String, CaseIterable {
    case favorites = "Favorites"
    case devices = "Devices"
    case recent = "Recent"
}

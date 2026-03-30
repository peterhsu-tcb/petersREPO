import Foundation

/// Represents a bookmark/favorite directory
struct BookmarkItem: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var icon: String
    let dateAdded: Date
    
    var url: URL {
        URL(fileURLWithPath: path)
    }
    
    init(name: String, path: String, icon: String = "folder.fill") {
        self.id = UUID()
        self.name = name
        self.path = path
        self.icon = icon
        self.dateAdded = Date()
    }
    
    init(url: URL, icon: String = "folder.fill") {
        self.id = UUID()
        self.name = url.lastPathComponent
        self.path = url.path
        self.icon = icon
        self.dateAdded = Date()
    }
}

/// Manages bookmarks persistence and operations
class BookmarkManager: ObservableObject {
    @Published var bookmarks: [BookmarkItem]
    
    private let bookmarksKey = "SwiftCommanderBookmarks"
    
    /// Default bookmarks for quick access
    static let defaultBookmarks: [BookmarkItem] = [
        BookmarkItem(name: "Home", path: FileManager.default.homeDirectoryForCurrentUser.path, icon: "house.fill"),
        BookmarkItem(name: "Desktop", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path, icon: "menubar.dock.rectangle"),
        BookmarkItem(name: "Documents", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path, icon: "doc.fill"),
        BookmarkItem(name: "Downloads", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path, icon: "arrow.down.circle.fill"),
        BookmarkItem(name: "Applications", path: "/Applications", icon: "app.fill"),
        BookmarkItem(name: "Root", path: "/", icon: "externaldrive.fill")
    ]
    
    init() {
        self.bookmarks = BookmarkManager.loadBookmarks()
    }
    
    /// Load bookmarks from UserDefaults
    private static func loadBookmarks() -> [BookmarkItem] {
        guard let data = UserDefaults.standard.data(forKey: "SwiftCommanderBookmarks"),
              let bookmarks = try? JSONDecoder().decode([BookmarkItem].self, from: data) else {
            return defaultBookmarks
        }
        return bookmarks
    }
    
    /// Save bookmarks to UserDefaults
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
    
    /// Add a new bookmark
    func addBookmark(_ bookmark: BookmarkItem) {
        // Check if bookmark already exists
        guard !bookmarks.contains(where: { $0.path == bookmark.path }) else {
            return
        }
        bookmarks.append(bookmark)
        saveBookmarks()
    }
    
    /// Add bookmark from URL
    func addBookmark(url: URL, name: String? = nil) {
        let bookmarkName = name ?? url.lastPathComponent
        let bookmark = BookmarkItem(name: bookmarkName, path: url.path)
        addBookmark(bookmark)
    }
    
    /// Remove a bookmark
    func removeBookmark(_ bookmark: BookmarkItem) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }
    
    /// Remove bookmark by ID
    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }
    
    /// Update a bookmark
    func updateBookmark(_ bookmark: BookmarkItem) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
            saveBookmarks()
        }
    }
    
    /// Move bookmark (for reordering)
    func moveBookmark(from source: IndexSet, to destination: Int) {
        bookmarks.move(fromOffsets: source, toOffset: destination)
        saveBookmarks()
    }
    
    /// Reset to default bookmarks
    func resetToDefaults() {
        bookmarks = BookmarkManager.defaultBookmarks
        saveBookmarks()
    }
    
    /// Check if a path is bookmarked
    func isBookmarked(path: String) -> Bool {
        bookmarks.contains { $0.path == path }
    }
    
    /// Get bookmark for a path
    func bookmark(for path: String) -> BookmarkItem? {
        bookmarks.first { $0.path == path }
    }
}

/// Recent directory history
class RecentDirectories: ObservableObject {
    @Published var directories: [URL]
    
    private let maxRecent = 20
    private let recentKey = "SwiftCommanderRecentDirectories"
    
    init() {
        self.directories = RecentDirectories.loadRecent()
    }
    
    /// Load recent directories from UserDefaults
    private static func loadRecent() -> [URL] {
        guard let paths = UserDefaults.standard.stringArray(forKey: "SwiftCommanderRecentDirectories") else {
            return []
        }
        return paths.compactMap { URL(fileURLWithPath: $0) }
    }
    
    /// Save recent directories to UserDefaults
    private func saveRecent() {
        let paths = directories.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentKey)
    }
    
    /// Add a directory to recent list
    func addRecent(_ url: URL) {
        // Remove if already exists
        directories.removeAll { $0 == url }
        
        // Add at the beginning
        directories.insert(url, at: 0)
        
        // Trim to max size
        if directories.count > maxRecent {
            directories = Array(directories.prefix(maxRecent))
        }
        
        saveRecent()
    }
    
    /// Clear recent directories
    func clear() {
        directories.removeAll()
        saveRecent()
    }
}

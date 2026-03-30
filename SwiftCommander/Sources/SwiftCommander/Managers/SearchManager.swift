import Foundation

/// Manages search functionality
class SearchManager: ObservableObject {
    static let shared = SearchManager()
    
    @Published var isSearching = false
    @Published var searchResults: [FileItem] = []
    @Published var searchProgress: String = ""
    
    private var searchTask: Task<Void, Never>?
    
    private init() {}
    
    /// Search types
    enum SearchType {
        case filename       // Search by filename only
        case content       // Search file contents
        case regex         // Regex filename search
        case spotlight     // Use Spotlight
    }
    
    /// Search for files matching a query
    func search(
        query: String,
        in directory: URL,
        type: SearchType = .filename,
        recursive: Bool = true,
        includeHidden: Bool = false
    ) async -> [FileItem] {
        guard !query.isEmpty else { return [] }
        
        await MainActor.run {
            isSearching = true
            searchResults = []
            searchProgress = "Searching..."
        }
        
        defer {
            Task { @MainActor in
                isSearching = false
                searchProgress = ""
            }
        }
        
        switch type {
        case .filename:
            return await searchByFilename(query: query, in: directory, recursive: recursive, includeHidden: includeHidden)
        case .content:
            return await searchByContent(query: query, in: directory, recursive: recursive, includeHidden: includeHidden)
        case .regex:
            return await searchByRegex(pattern: query, in: directory, recursive: recursive, includeHidden: includeHidden)
        case .spotlight:
            return await spotlightSearch(query: query, in: directory)
        }
    }
    
    /// Cancel ongoing search
    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }
    
    // MARK: - Private Search Methods
    
    private func searchByFilename(
        query: String,
        in directory: URL,
        recursive: Bool,
        includeHidden: Bool
    ) async -> [FileItem] {
        var results: [FileItem] = []
        let lowercasedQuery = query.lowercased()
        
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled { break }
            
            // Skip hidden files if not included
            if !includeHidden {
                if let isHidden = try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden, isHidden {
                    continue
                }
            }
            
            if url.lastPathComponent.lowercased().contains(lowercasedQuery) {
                results.append(FileItem(url: url))
                
                await MainActor.run {
                    searchResults = results
                    searchProgress = "Found \(results.count) items..."
                }
            }
        }
        
        return results
    }
    
    private func searchByContent(
        query: String,
        in directory: URL,
        recursive: Bool,
        includeHidden: Bool
    ) async -> [FileItem] {
        var results: [FileItem] = []
        let lowercasedQuery = query.lowercased()
        
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled { break }
            
            // Skip directories
            if let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory {
                continue
            }
            
            // Skip hidden files if not included
            if !includeHidden {
                if let isHidden = try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden, isHidden {
                    continue
                }
            }
            
            // Skip binary files (basic check)
            if isBinaryFile(url) {
                continue
            }
            
            // Read and search file content
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                if content.lowercased().contains(lowercasedQuery) {
                    results.append(FileItem(url: url))
                    
                    await MainActor.run {
                        searchResults = results
                        searchProgress = "Found \(results.count) items..."
                    }
                }
            }
        }
        
        return results
    }
    
    private func searchByRegex(
        pattern: String,
        in directory: URL,
        recursive: Bool,
        includeHidden: Bool
    ) async -> [FileItem] {
        var results: [FileItem] = []
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled { break }
            
            // Skip hidden files if not included
            if !includeHidden {
                if let isHidden = try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden, isHidden {
                    continue
                }
            }
            
            let filename = url.lastPathComponent
            let range = NSRange(filename.startIndex..., in: filename)
            
            if regex.firstMatch(in: filename, options: [], range: range) != nil {
                results.append(FileItem(url: url))
                
                await MainActor.run {
                    searchResults = results
                    searchProgress = "Found \(results.count) items..."
                }
            }
        }
        
        return results
    }
    
    private func spotlightSearch(query: String, in directory: URL) async -> [FileItem] {
        return await withCheckedContinuation { continuation in
            let mdQuery = NSMetadataQuery()
            mdQuery.searchScopes = [directory]
            mdQuery.predicate = NSPredicate(format: "kMDItemFSName CONTAINS[cd] %@", query)
            
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: mdQuery,
                queue: .main
            ) { _ in
                mdQuery.stop()
                
                var results: [FileItem] = []
                for item in mdQuery.results {
                    if let mdItem = item as? NSMetadataItem,
                       let path = mdItem.value(forAttribute: kMDItemPath as String) as? String {
                        results.append(FileItem(url: URL(fileURLWithPath: path)))
                    }
                }
                
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                }
                
                continuation.resume(returning: results)
            }
            
            mdQuery.start()
        }
    }
    
    // MARK: - Helpers
    
    /// Basic binary file detection
    private func isBinaryFile(_ url: URL) -> Bool {
        let binaryExtensions = ["exe", "dll", "so", "dylib", "bin", "dat", 
                                "jpg", "jpeg", "png", "gif", "bmp", "tiff",
                                "mp3", "wav", "mp4", "mov", "avi",
                                "pdf", "doc", "docx", "xls", "xlsx",
                                "zip", "tar", "gz", "rar", "7z",
                                "app", "dmg", "pkg"]
        return binaryExtensions.contains(url.pathExtension.lowercased())
    }
}

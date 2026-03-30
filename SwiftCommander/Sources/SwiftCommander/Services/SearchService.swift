import Foundation

/// Service for searching files
class SearchService {
    
    private let fileManager = FileManager.default
    
    /// Search criteria
    struct SearchCriteria {
        var namePattern: String
        var searchInSubdirectories: Bool
        var caseSensitive: Bool
        var useRegex: Bool
        var fileTypesFilter: Set<FileType>?
        var minSize: Int64?
        var maxSize: Int64?
        var modifiedAfter: Date?
        var modifiedBefore: Date?
        var includeHidden: Bool
        
        init(
            namePattern: String = "",
            searchInSubdirectories: Bool = true,
            caseSensitive: Bool = false,
            useRegex: Bool = false,
            fileTypesFilter: Set<FileType>? = nil,
            minSize: Int64? = nil,
            maxSize: Int64? = nil,
            modifiedAfter: Date? = nil,
            modifiedBefore: Date? = nil,
            includeHidden: Bool = false
        ) {
            self.namePattern = namePattern
            self.searchInSubdirectories = searchInSubdirectories
            self.caseSensitive = caseSensitive
            self.useRegex = useRegex
            self.fileTypesFilter = fileTypesFilter
            self.minSize = minSize
            self.maxSize = maxSize
            self.modifiedAfter = modifiedAfter
            self.modifiedBefore = modifiedBefore
            self.includeHidden = includeHidden
        }
    }
    
    /// Search result
    struct SearchResult {
        let items: [FileItem]
        let searchTime: TimeInterval
        let totalFound: Int
        let wasLimited: Bool
    }
    
    // MARK: - Search Operations
    
    /// Search for files matching criteria
    func search(
        in directory: URL,
        criteria: SearchCriteria,
        limit: Int = 1000,
        progress: ((Int) -> Void)? = nil
    ) -> SearchResult {
        let startTime = Date()
        var results: [FileItem] = []
        var totalFound = 0
        var wasLimited = false
        
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isHiddenKey,
                .isSymbolicLinkKey
            ],
            options: criteria.searchInSubdirectories ? [] : [.skipsSubdirectoryDescendants]
        )
        
        while let url = enumerator?.nextObject() as? URL {
            if let item = FileItem.from(url: url) {
                if matches(item: item, criteria: criteria) {
                    totalFound += 1
                    
                    if results.count < limit {
                        results.append(item)
                        progress?(results.count)
                    } else {
                        wasLimited = true
                    }
                }
            }
        }
        
        let searchTime = Date().timeIntervalSince(startTime)
        
        return SearchResult(
            items: results,
            searchTime: searchTime,
            totalFound: totalFound,
            wasLimited: wasLimited
        )
    }
    
    /// Quick search in a single directory (for filtering)
    func quickSearch(in files: [FileItem], pattern: String, caseSensitive: Bool = false) -> [FileItem] {
        if pattern.isEmpty {
            return files
        }
        
        if caseSensitive {
            return files.filter { $0.name.contains(pattern) }
        } else {
            return files.filter { $0.name.localizedCaseInsensitiveContains(pattern) }
        }
    }
    
    /// Filter files by type
    func filter(files: [FileItem], byTypes types: Set<FileType>) -> [FileItem] {
        return files.filter { types.contains($0.fileType) }
    }
    
    /// Filter files by extension
    func filter(files: [FileItem], byExtensions extensions: Set<String>) -> [FileItem] {
        let lowercasedExtensions = Set(extensions.map { $0.lowercased() })
        return files.filter { lowercasedExtensions.contains($0.fileExtension) }
    }
    
    // MARK: - Content Search
    
    /// Search for files containing text
    func searchContent(
        in directory: URL,
        text: String,
        caseSensitive: Bool = false,
        fileExtensions: Set<String>? = nil,
        limit: Int = 100,
        progress: ((Int, String) -> Void)? = nil
    ) -> SearchResult {
        let startTime = Date()
        var results: [FileItem] = []
        var totalFound = 0
        var wasLimited = false
        var filesSearched = 0
        
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: []
        )
        
        while let url = enumerator?.nextObject() as? URL {
            // Skip directories
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                continue
            }
            
            // Filter by extension if specified
            if let extensions = fileExtensions {
                let ext = url.pathExtension.lowercased()
                if !extensions.contains(ext) {
                    continue
                }
            }
            
            filesSearched += 1
            progress?(filesSearched, url.lastPathComponent)
            
            // Read file and search
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let found: Bool
                if caseSensitive {
                    found = content.contains(text)
                } else {
                    found = content.localizedCaseInsensitiveContains(text)
                }
                
                if found {
                    totalFound += 1
                    
                    if results.count < limit {
                        if let item = FileItem.from(url: url) {
                            results.append(item)
                        }
                    } else {
                        wasLimited = true
                    }
                }
            }
        }
        
        let searchTime = Date().timeIntervalSince(startTime)
        
        return SearchResult(
            items: results,
            searchTime: searchTime,
            totalFound: totalFound,
            wasLimited: wasLimited
        )
    }
    
    // MARK: - Helper Methods
    
    private func matches(item: FileItem, criteria: SearchCriteria) -> Bool {
        // Check hidden files
        if !criteria.includeHidden && item.isHidden {
            return false
        }
        
        // Check name pattern
        if !criteria.namePattern.isEmpty {
            if criteria.useRegex {
                if !matchesRegex(item.name, pattern: criteria.namePattern, caseSensitive: criteria.caseSensitive) {
                    return false
                }
            } else {
                if criteria.caseSensitive {
                    if !item.name.contains(criteria.namePattern) {
                        return false
                    }
                } else {
                    if !item.name.localizedCaseInsensitiveContains(criteria.namePattern) {
                        return false
                    }
                }
            }
        }
        
        // Check file types
        if let types = criteria.fileTypesFilter, !item.isDirectory {
            if !types.contains(item.fileType) {
                return false
            }
        }
        
        // Check size
        if let minSize = criteria.minSize, item.size < minSize {
            return false
        }
        if let maxSize = criteria.maxSize, item.size > maxSize {
            return false
        }
        
        // Check modification date
        if let after = criteria.modifiedAfter, item.modificationDate < after {
            return false
        }
        if let before = criteria.modifiedBefore, item.modificationDate > before {
            return false
        }
        
        return true
    }
    
    private func matchesRegex(_ text: String, pattern: String, caseSensitive: Bool) -> Bool {
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    /// Convert wildcard pattern to regex
    func wildcardToRegex(_ pattern: String) -> String {
        var regex = ""
        for char in pattern {
            switch char {
            case "*":
                regex += ".*"
            case "?":
                regex += "."
            case ".":
                regex += "\\."
            case "[", "]", "(", ")", "{", "}", "^", "$", "|", "+", "\\":
                regex += "\\\(char)"
            default:
                regex += String(char)
            }
        }
        return "^" + regex + "$"
    }
}

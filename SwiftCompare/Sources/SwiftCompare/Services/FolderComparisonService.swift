import Foundation

/// Service for comparing folders and their contents
class FolderComparisonService {
    private let fileComparisonService = FileComparisonService()
    private let fileManager = FileManager.default
    
    /// Compare two folders and return the comparison result
    func compareFolders(leftURL: URL, rightURL: URL, recursive: Bool = true) -> FolderComparisonResult {
        let items = compareDirectory(leftURL: leftURL, rightURL: rightURL, recursive: recursive)
        return FolderComparisonResult(leftFolder: leftURL, rightFolder: rightURL, items: items)
    }
    
    /// Compare contents of two directories
    private func compareDirectory(leftURL: URL, rightURL: URL, recursive: Bool) -> [ComparisonItem] {
        var result: [ComparisonItem] = []
        
        // Get contents of both directories
        let leftContents = getDirectoryContents(leftURL)
        let rightContents = getDirectoryContents(rightURL)
        
        // Create sets of file names
        let leftNames = Set(leftContents.map { $0.name })
        let rightNames = Set(rightContents.map { $0.name })
        let allNames = leftNames.union(rightNames).sorted()
        
        // Create lookup dictionaries
        let leftDict = Dictionary(uniqueKeysWithValues: leftContents.map { ($0.name, $0) })
        let rightDict = Dictionary(uniqueKeysWithValues: rightContents.map { ($0.name, $0) })
        
        for name in allNames {
            let leftItem = leftDict[name]
            let rightItem = rightDict[name]
            
            let status: ComparisonStatus
            let isDirectory: Bool
            var children: [ComparisonItem]?
            
            if let left = leftItem, let right = rightItem {
                // Both exist
                isDirectory = left.isDirectory && right.isDirectory
                
                if left.isDirectory != right.isDirectory {
                    // One is file, other is directory
                    status = .different
                } else if isDirectory {
                    // Both are directories
                    if recursive {
                        children = compareDirectory(
                            leftURL: left.url,
                            rightURL: right.url,
                            recursive: true
                        )
                        // Determine status based on children
                        if let childItems = children {
                            let hasChanges = childItems.contains { item in
                                item.status != .identical
                            }
                            status = hasChanges ? .different : .identical
                        } else {
                            status = .identical
                        }
                    } else {
                        status = .identical
                    }
                } else {
                    // Both are files - compare content
                    status = compareFileContents(left.url, right.url)
                }
            } else if leftItem != nil {
                // Only exists on left
                isDirectory = leftItem!.isDirectory
                status = .leftOnly
                if isDirectory && recursive {
                    children = getItemsAsLeftOnly(leftItem!.url)
                }
            } else {
                // Only exists on right
                isDirectory = rightItem!.isDirectory
                status = .rightOnly
                if isDirectory && recursive {
                    children = getItemsAsRightOnly(rightItem!.url)
                }
            }
            
            result.append(ComparisonItem(
                name: name,
                leftItem: leftItem,
                rightItem: rightItem,
                status: status,
                isDirectory: isDirectory,
                children: children
            ))
        }
        
        return result
    }
    
    /// Get contents of a directory
    private func getDirectoryContents(_ url: URL) -> [FileItem] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return contents.map { FileItem(url: $0) }
    }
    
    /// Compare file contents and return status
    private func compareFileContents(_ leftURL: URL, _ rightURL: URL) -> ComparisonStatus {
        // First compare file sizes
        let leftSize = (try? fileManager.attributesOfItem(atPath: leftURL.path)[.size] as? Int64) ?? 0
        let rightSize = (try? fileManager.attributesOfItem(atPath: rightURL.path)[.size] as? Int64) ?? 0
        
        if leftSize != rightSize {
            return .different
        }
        
        // If sizes match, compare content
        if fileComparisonService.isBinaryFile(leftURL) || fileComparisonService.isBinaryFile(rightURL) {
            return fileComparisonService.compareBinaryFiles(leftURL: leftURL, rightURL: rightURL)
                ? .identical : .different
        }
        
        // Text file comparison
        let leftContent = try? String(contentsOf: leftURL, encoding: .utf8)
        let rightContent = try? String(contentsOf: rightURL, encoding: .utf8)
        
        if leftContent == nil && rightContent == nil {
            return .error("Unable to read both files: \(leftURL.lastPathComponent) and \(rightURL.lastPathComponent)")
        } else if leftContent == nil {
            return .error("Unable to read left file: \(leftURL.lastPathComponent)")
        } else if rightContent == nil {
            return .error("Unable to read right file: \(rightURL.lastPathComponent)")
        }
        
        return leftContent == rightContent ? .identical : .different
    }
    
    /// Get all items in a directory marked as left only
    private func getItemsAsLeftOnly(_ url: URL) -> [ComparisonItem] {
        let contents = getDirectoryContents(url)
        return contents.map { item in
            var children: [ComparisonItem]?
            if item.isDirectory {
                children = getItemsAsLeftOnly(item.url)
            }
            return ComparisonItem(
                name: item.name,
                leftItem: item,
                rightItem: nil,
                status: .leftOnly,
                isDirectory: item.isDirectory,
                children: children
            )
        }
    }
    
    /// Get all items in a directory marked as right only
    private func getItemsAsRightOnly(_ url: URL) -> [ComparisonItem] {
        let contents = getDirectoryContents(url)
        return contents.map { item in
            var children: [ComparisonItem]?
            if item.isDirectory {
                children = getItemsAsRightOnly(item.url)
            }
            return ComparisonItem(
                name: item.name,
                leftItem: nil,
                rightItem: item,
                status: .rightOnly,
                isDirectory: item.isDirectory,
                children: children
            )
        }
    }
    
    /// Synchronize files from source to destination
    func synchronize(
        from sourceURL: URL,
        to destinationURL: URL,
        overwrite: Bool = false
    ) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            if overwrite {
                try fileManager.removeItem(at: destinationURL)
            } else {
                throw SyncError.fileExists
            }
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    
    /// Delete a file or directory
    func delete(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
}

/// Errors that can occur during synchronization
enum SyncError: Error, LocalizedError {
    case fileExists
    case copyFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .fileExists:
            return "File already exists at destination"
        case .copyFailed:
            return "Failed to copy file"
        case .deleteFailed:
            return "Failed to delete file"
        }
    }
}

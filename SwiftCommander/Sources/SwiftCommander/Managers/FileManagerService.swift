import Foundation

/// Manages file system operations
class FileManagerService: ObservableObject {
    static let shared = FileManagerService()
    
    private let fileManager = FileManager.default
    @Published var isOperationInProgress = false
    @Published var currentProgress: FileOperationProgress?
    
    private init() {}
    
    // MARK: - Directory Listing
    
    /// List contents of a directory
    func listDirectory(at url: URL, showHidden: Bool = false) throws -> [FileItem] {
        var items: [FileItem] = []
        
        // Add parent directory entry if not at root
        if url.path != "/" {
            items.append(FileItem.parentDirectory)
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isHiddenKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ],
            options: showHidden ? [] : [.skipsHiddenFiles]
        )
        
        for itemURL in contents {
            items.append(FileItem(url: itemURL))
        }
        
        return items.sorted()
    }
    
    // MARK: - File Operations
    
    /// Copy items to destination
    func copyItems(_ sources: [URL], to destination: URL, conflictHandler: @escaping (URL) async -> ConflictResolution) async throws {
        isOperationInProgress = true
        defer { isOperationInProgress = false }
        
        var skipAll = false
        var replaceAll = false
        
        for (index, source) in sources.enumerated() {
            let destinationURL = destination.appendingPathComponent(source.lastPathComponent)
            
            currentProgress = FileOperationProgress(
                currentFile: source.lastPathComponent,
                currentIndex: index + 1,
                totalFiles: sources.count,
                bytesCompleted: 0,
                totalBytes: 0
            )
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                if skipAll {
                    continue
                }
                
                let resolution: ConflictResolution
                if replaceAll {
                    resolution = .replace
                } else {
                    resolution = await conflictHandler(destinationURL)
                }
                
                switch resolution {
                case .replace:
                    try fileManager.removeItem(at: destinationURL)
                    try fileManager.copyItem(at: source, to: destinationURL)
                case .keepBoth:
                    let newURL = generateUniqueName(for: destinationURL)
                    try fileManager.copyItem(at: source, to: newURL)
                case .skip:
                    continue
                case .skipAll:
                    skipAll = true
                    continue
                case .replaceAll:
                    replaceAll = true
                    try fileManager.removeItem(at: destinationURL)
                    try fileManager.copyItem(at: source, to: destinationURL)
                }
            } else {
                try fileManager.copyItem(at: source, to: destinationURL)
            }
        }
        
        currentProgress = nil
    }
    
    /// Move items to destination
    func moveItems(_ sources: [URL], to destination: URL, conflictHandler: @escaping (URL) async -> ConflictResolution) async throws {
        isOperationInProgress = true
        defer { isOperationInProgress = false }
        
        var skipAll = false
        var replaceAll = false
        
        for (index, source) in sources.enumerated() {
            let destinationURL = destination.appendingPathComponent(source.lastPathComponent)
            
            currentProgress = FileOperationProgress(
                currentFile: source.lastPathComponent,
                currentIndex: index + 1,
                totalFiles: sources.count,
                bytesCompleted: 0,
                totalBytes: 0
            )
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                if skipAll {
                    continue
                }
                
                let resolution: ConflictResolution
                if replaceAll {
                    resolution = .replace
                } else {
                    resolution = await conflictHandler(destinationURL)
                }
                
                switch resolution {
                case .replace:
                    try fileManager.removeItem(at: destinationURL)
                    try fileManager.moveItem(at: source, to: destinationURL)
                case .keepBoth:
                    let newURL = generateUniqueName(for: destinationURL)
                    try fileManager.moveItem(at: source, to: newURL)
                case .skip:
                    continue
                case .skipAll:
                    skipAll = true
                    continue
                case .replaceAll:
                    replaceAll = true
                    try fileManager.removeItem(at: destinationURL)
                    try fileManager.moveItem(at: source, to: destinationURL)
                }
            } else {
                try fileManager.moveItem(at: source, to: destinationURL)
            }
        }
        
        currentProgress = nil
    }
    
    /// Delete items (move to trash)
    func deleteItems(_ urls: [URL], permanently: Bool = false) throws {
        for url in urls {
            if permanently {
                try fileManager.removeItem(at: url)
            } else {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            }
        }
    }
    
    /// Rename a file or folder
    func rename(at url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: url, to: newURL)
        return newURL
    }
    
    /// Create a new folder
    func createFolder(at parentURL: URL, name: String) throws -> URL {
        let folderURL = parentURL.appendingPathComponent(name)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return folderURL
    }
    
    /// Create a new empty file
    func createFile(at parentURL: URL, name: String) throws -> URL {
        let fileURL = parentURL.appendingPathComponent(name)
        fileManager.createFile(atPath: fileURL.path, contents: nil)
        return fileURL
    }
    
    // MARK: - Helpers
    
    /// Generate a unique filename when there's a conflict
    func generateUniqueName(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newURL: URL
        
        repeat {
            let newName = ext.isEmpty ? "\(filename) (\(counter))" : "\(filename) (\(counter)).\(ext)"
            newURL = directory.appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path)
        
        return newURL
    }
    
    /// Calculate total size of items
    func calculateSize(of urls: [URL]) -> Int64 {
        var totalSize: Int64 = 0
        
        for url in urls {
            if let resources = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) {
                if resources.isDirectory == true {
                    totalSize += calculateDirectorySize(at: url)
                } else {
                    totalSize += Int64(resources.fileSize ?? 0)
                }
            }
        }
        
        return totalSize
    }
    
    /// Calculate size of a directory recursively
    func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                    size += Int64(resources.fileSize ?? 0)
                }
            }
        }
        
        return size
    }
    
    /// Check if a path is writable
    func isWritable(at url: URL) -> Bool {
        fileManager.isWritableFile(atPath: url.path)
    }
    
    /// Get available disk space
    func availableSpace(at url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]) {
            return Int64(values.volumeAvailableCapacity ?? 0)
        }
        return 0
    }
}

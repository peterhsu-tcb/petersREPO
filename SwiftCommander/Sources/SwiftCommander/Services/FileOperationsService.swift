import Foundation

/// Service for file system operations
class FileOperationsService {
    
    /// Error types for file operations
    enum FileOperationError: Error, LocalizedError {
        case sourceNotFound(String)
        case destinationExists(String)
        case permissionDenied(String)
        case operationFailed(String)
        case invalidOperation(String)
        
        var errorDescription: String? {
            switch self {
            case .sourceNotFound(let path):
                return "Source not found: \(path)"
            case .destinationExists(let path):
                return "Destination already exists: \(path)"
            case .permissionDenied(let path):
                return "Permission denied: \(path)"
            case .operationFailed(let message):
                return "Operation failed: \(message)"
            case .invalidOperation(let message):
                return "Invalid operation: \(message)"
            }
        }
    }
    
    /// Result of a file operation
    struct OperationResult {
        let success: Bool
        let message: String
        let affectedItems: Int
    }
    
    private let fileManager = FileManager.default
    
    // MARK: - Directory Listing
    
    /// List contents of a directory
    func listDirectory(at url: URL) throws -> [FileItem] {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isHiddenKey,
                .isSymbolicLinkKey
            ],
            options: []
        )
        
        return contents.compactMap { FileItem.from(url: $0) }
    }
    
    // MARK: - Copy Operations
    
    /// Copy a single file or directory
    func copy(from source: URL, to destination: URL, overwrite: Bool = false) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw FileOperationError.sourceNotFound(source.path)
        }
        
        let destinationPath = destination.appendingPathComponent(source.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationPath.path) {
            if overwrite {
                try fileManager.removeItem(at: destinationPath)
            } else {
                throw FileOperationError.destinationExists(destinationPath.path)
            }
        }
        
        try fileManager.copyItem(at: source, to: destinationPath)
    }
    
    /// Copy multiple files to a destination directory
    func copyMultiple(sources: [URL], to destination: URL, overwrite: Bool = false) throws -> OperationResult {
        var successCount = 0
        var errors: [String] = []
        
        for source in sources {
            do {
                try copy(from: source, to: destination, overwrite: overwrite)
                successCount += 1
            } catch {
                errors.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        let success = errors.isEmpty
        let message = success 
            ? "Copied \(successCount) items"
            : "Copied \(successCount)/\(sources.count) items. Errors: \(errors.joined(separator: "; "))"
        
        return OperationResult(success: success, message: message, affectedItems: successCount)
    }
    
    // MARK: - Move Operations
    
    /// Move a single file or directory
    func move(from source: URL, to destination: URL, overwrite: Bool = false) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw FileOperationError.sourceNotFound(source.path)
        }
        
        let destinationPath = destination.appendingPathComponent(source.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationPath.path) {
            if overwrite {
                try fileManager.removeItem(at: destinationPath)
            } else {
                throw FileOperationError.destinationExists(destinationPath.path)
            }
        }
        
        try fileManager.moveItem(at: source, to: destinationPath)
    }
    
    /// Move multiple files to a destination directory
    func moveMultiple(sources: [URL], to destination: URL, overwrite: Bool = false) throws -> OperationResult {
        var successCount = 0
        var errors: [String] = []
        
        for source in sources {
            do {
                try move(from: source, to: destination, overwrite: overwrite)
                successCount += 1
            } catch {
                errors.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        let success = errors.isEmpty
        let message = success 
            ? "Moved \(successCount) items"
            : "Moved \(successCount)/\(sources.count) items. Errors: \(errors.joined(separator: "; "))"
        
        return OperationResult(success: success, message: message, affectedItems: successCount)
    }
    
    // MARK: - Delete Operations
    
    /// Delete a single file or directory
    func delete(at url: URL, moveToTrash: Bool = true) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileOperationError.sourceNotFound(url.path)
        }
        
        if moveToTrash {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } else {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Delete multiple files
    func deleteMultiple(urls: [URL], moveToTrash: Bool = true) throws -> OperationResult {
        var successCount = 0
        var errors: [String] = []
        
        for url in urls {
            do {
                try delete(at: url, moveToTrash: moveToTrash)
                successCount += 1
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        let success = errors.isEmpty
        let message = success 
            ? "Deleted \(successCount) items"
            : "Deleted \(successCount)/\(urls.count) items. Errors: \(errors.joined(separator: "; "))"
        
        return OperationResult(success: success, message: message, affectedItems: successCount)
    }
    
    // MARK: - Rename Operations
    
    /// Rename a file or directory
    func rename(at url: URL, to newName: String) throws -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileOperationError.sourceNotFound(url.path)
        }
        
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        
        if fileManager.fileExists(atPath: newURL.path) {
            throw FileOperationError.destinationExists(newURL.path)
        }
        
        try fileManager.moveItem(at: url, to: newURL)
        return newURL
    }
    
    // MARK: - Create Operations
    
    /// Create a new directory
    func createDirectory(at url: URL, named name: String) throws -> URL {
        let newDirURL = url.appendingPathComponent(name)
        
        if fileManager.fileExists(atPath: newDirURL.path) {
            throw FileOperationError.destinationExists(newDirURL.path)
        }
        
        try fileManager.createDirectory(at: newDirURL, withIntermediateDirectories: false)
        return newDirURL
    }
    
    /// Create a new empty file
    func createFile(at url: URL, named name: String, contents: Data? = nil) throws -> URL {
        let newFileURL = url.appendingPathComponent(name)
        
        if fileManager.fileExists(atPath: newFileURL.path) {
            throw FileOperationError.destinationExists(newFileURL.path)
        }
        
        let success = fileManager.createFile(atPath: newFileURL.path, contents: contents)
        
        if !success {
            throw FileOperationError.operationFailed("Could not create file: \(name)")
        }
        
        return newFileURL
    }
    
    // MARK: - File Information
    
    /// Get file attributes
    func attributes(at url: URL) throws -> [FileAttributeKey: Any] {
        return try fileManager.attributesOfItem(atPath: url.path)
    }
    
    /// Check if path exists
    func exists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Check if path is a directory
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
    
    /// Check if path is readable
    func isReadable(at url: URL) -> Bool {
        return fileManager.isReadableFile(atPath: url.path)
    }
    
    /// Check if path is writable
    func isWritable(at url: URL) -> Bool {
        return fileManager.isWritableFile(atPath: url.path)
    }
    
    /// Get disk space information
    func diskSpace(at url: URL) throws -> (total: Int64, free: Int64, used: Int64) {
        let attributes = try fileManager.attributesOfFileSystem(forPath: url.path)
        let total = (attributes[.systemSize] as? Int64) ?? 0
        let free = (attributes[.systemFreeSize] as? Int64) ?? 0
        return (total, free, total - free)
    }
    
    // MARK: - Symbolic Links
    
    /// Create a symbolic link
    func createSymbolicLink(at url: URL, named name: String, destination: URL) throws -> URL {
        let linkURL = url.appendingPathComponent(name)
        
        if fileManager.fileExists(atPath: linkURL.path) {
            throw FileOperationError.destinationExists(linkURL.path)
        }
        
        try fileManager.createSymbolicLink(at: linkURL, withDestinationURL: destination)
        return linkURL
    }
    
    /// Resolve symbolic link destination
    func resolveSymbolicLink(at url: URL) throws -> URL {
        let destination = try fileManager.destinationOfSymbolicLink(atPath: url.path)
        return URL(fileURLWithPath: destination)
    }
    
    // MARK: - Permissions
    
    /// Set file permissions
    func setPermissions(at url: URL, permissions: Int) throws {
        try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }
    
    /// Make file executable
    func makeExecutable(at url: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let currentPermissions = (attributes[.posixPermissions] as? Int) ?? 0o644
        let newPermissions = currentPermissions | 0o111
        try setPermissions(at: url, permissions: newPermissions)
    }
}

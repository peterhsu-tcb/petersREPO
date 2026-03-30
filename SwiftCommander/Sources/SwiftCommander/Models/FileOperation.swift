import Foundation

/// File operations result
enum FileOperationResult {
    case success
    case failure(Error)
    case cancelled
}

/// Conflict resolution options
enum ConflictResolution {
    case replace
    case keepBoth
    case skip
    case skipAll
    case replaceAll
}

/// Progress information for file operations
struct FileOperationProgress {
    let currentFile: String
    let currentIndex: Int
    let totalFiles: Int
    let bytesCompleted: Int64
    let totalBytes: Int64
    
    var percentComplete: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesCompleted) / Double(totalBytes) * 100
    }
    
    var filePercentComplete: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(currentIndex) / Double(totalFiles) * 100
    }
}

/// File operation types
enum FileOperationType {
    case copy
    case move
    case delete
    case rename
    case createFolder
    case createFile
    case archive
    case extract
}

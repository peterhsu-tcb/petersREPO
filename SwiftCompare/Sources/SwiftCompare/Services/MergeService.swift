import Foundation

/// Service for merging differences between files
class MergeService {
    private let fileManager = FileManager.default
    private let backupService = BackupService()
    
    /// Errors that can occur during merge operations
    enum MergeError: Error, LocalizedError {
        case fileNotFound(String)
        case readError(String)
        case writeError(String)
        case invalidChunkIndex
        case mergeConflict(String)
        case backupError(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .readError(let message):
                return "Failed to read file: \(message)"
            case .writeError(let message):
                return "Failed to write file: \(message)"
            case .invalidChunkIndex:
                return "Invalid chunk index specified"
            case .mergeConflict(let message):
                return "Merge conflict: \(message)"
            case .backupError(let message):
                return "Backup failed: \(message)"
            }
        }
    }
    
    /// Result of a merge operation
    struct MergeResult {
        let success: Bool
        let mergedContent: String
        let changesApplied: Int
        let message: String
        /// URL of the backup file created before merge (nil if backup was disabled)
        let backupURL: URL?
        
        init(success: Bool, mergedContent: String, changesApplied: Int, message: String, backupURL: URL? = nil) {
            self.success = success
            self.mergedContent = mergedContent
            self.changesApplied = changesApplied
            self.message = message
            self.backupURL = backupURL
        }
    }
    
    // MARK: - Chunk-level Merge Operations
    
    /// Merge a specific chunk from source to destination
    /// - Parameters:
    ///   - chunk: The diff chunk to merge
    ///   - destinationLines: Lines from the destination file
    ///   - direction: The merge direction (.leftToRight or .rightToLeft)
    /// - Returns: The merged lines array
    func mergeChunk(
        chunk: DiffChunk,
        destinationLines: [String],
        direction: MergeDirection
    ) -> [String] {
        var result = destinationLines
        
        switch direction {
        case .leftToRight:
            // Replace right side with left side content
            // The chunk contains lines from both sides
            // We need to replace right lines at rightStartLine with left lines
            let insertIndex = max(0, chunk.rightStartLine - 1)
            let removeCount = chunk.rightLineCount
            let insertLines = chunk.leftLines.map { $0.content }
            
            // Remove old lines
            let removeStart = min(insertIndex, result.count)
            let removeEnd = min(removeStart + removeCount, result.count)
            if removeEnd > removeStart {
                result.removeSubrange(removeStart..<removeEnd)
            }
            
            // Insert new lines
            let safeInsertIndex = min(removeStart, result.count)
            result.insert(contentsOf: insertLines, at: safeInsertIndex)
            
        case .rightToLeft:
            // Replace left side with right side content
            let insertIndex = max(0, chunk.leftStartLine - 1)
            let removeCount = chunk.leftLineCount
            let insertLines = chunk.rightLines.map { $0.content }
            
            // Remove old lines
            let removeStart = min(insertIndex, result.count)
            let removeEnd = min(removeStart + removeCount, result.count)
            if removeEnd > removeStart {
                result.removeSubrange(removeStart..<removeEnd)
            }
            
            // Insert new lines
            let safeInsertIndex = min(removeStart, result.count)
            result.insert(contentsOf: insertLines, at: safeInsertIndex)
        }
        
        return result
    }
    
    /// Merge a specific chunk at the given index and write to the destination file
    /// - Parameters:
    ///   - chunkIndex: Index of the chunk in the diff result
    ///   - diffResult: The full diff result containing all chunks
    ///   - direction: The merge direction
    ///   - createBackup: Whether to create a backup before merging (default: true)
    /// - Returns: MergeResult indicating success/failure and details
    func mergeChunkAtIndex(
        chunkIndex: Int,
        diffResult: DiffResult,
        direction: MergeDirection,
        createBackup: Bool = true
    ) throws -> MergeResult {
        guard chunkIndex >= 0 && chunkIndex < diffResult.chunks.count else {
            throw MergeError.invalidChunkIndex
        }
        
        let chunk = diffResult.chunks[chunkIndex]
        
        // Determine source and destination based on direction
        let (sourceURL, destinationURL): (URL?, URL?)
        switch direction {
        case .leftToRight:
            sourceURL = diffResult.leftFile
            destinationURL = diffResult.rightFile
        case .rightToLeft:
            sourceURL = diffResult.rightFile
            destinationURL = diffResult.leftFile
        }
        
        guard let destURL = destinationURL else {
            throw MergeError.fileNotFound("Destination file not specified")
        }
        
        // Create backup before merge if requested
        var backupURL: URL? = nil
        if createBackup {
            do {
                let backupInfo = try backupService.createBackup(of: destURL)
                backupURL = backupInfo.backupURL
            } catch {
                throw MergeError.backupError(error.localizedDescription)
            }
        }
        
        // Read destination file
        let destinationContent: String
        do {
            destinationContent = try String(contentsOf: destURL, encoding: .utf8)
        } catch {
            throw MergeError.readError(error.localizedDescription)
        }
        
        let destinationLines = destinationContent.components(separatedBy: .newlines)
        
        // Merge the chunk into the destination
        let mergedLines = mergeChunk(
            chunk: chunk,
            destinationLines: destinationLines,
            direction: direction
        )
        
        let mergedContent = mergedLines.joined(separator: "\n")
        
        // Write to destination
        do {
            try mergedContent.write(to: destURL, atomically: true, encoding: .utf8)
        } catch {
            throw MergeError.writeError(error.localizedDescription)
        }
        
        return MergeResult(
            success: true,
            mergedContent: mergedContent,
            changesApplied: 1,
            message: "Successfully merged chunk \(chunkIndex + 1)",
            backupURL: backupURL
        )
    }
    
    // MARK: - Full File Merge Operations
    
    /// Merge all differences from left to right
    /// - Parameters:
    ///   - diffResult: The diff result containing all differences
    ///   - createBackup: Whether to create a backup before merging (default: true)
    /// - Returns: MergeResult indicating success/failure and details
    func mergeAllLeftToRight(diffResult: DiffResult, createBackup: Bool = true) throws -> MergeResult {
        guard let destinationURL = diffResult.rightFile else {
            throw MergeError.fileNotFound("Right file not specified")
        }
        
        guard let sourceURL = diffResult.leftFile else {
            throw MergeError.fileNotFound("Left file not specified")
        }
        
        // Create backup before merge if requested
        var backupURL: URL? = nil
        if createBackup && fileManager.fileExists(atPath: destinationURL.path) {
            do {
                let backupInfo = try backupService.createBackup(of: destinationURL)
                backupURL = backupInfo.backupURL
            } catch {
                throw MergeError.backupError(error.localizedDescription)
            }
        }
        
        // Simply copy the entire left file to right
        let sourceContent: String
        do {
            sourceContent = try String(contentsOf: sourceURL, encoding: .utf8)
        } catch {
            throw MergeError.readError(error.localizedDescription)
        }
        
        do {
            try sourceContent.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            throw MergeError.writeError(error.localizedDescription)
        }
        
        return MergeResult(
            success: true,
            mergedContent: sourceContent,
            changesApplied: diffResult.chunks.count,
            message: "Successfully merged all \(diffResult.chunks.count) chunks from left to right",
            backupURL: backupURL
        )
    }
    
    /// Merge all differences from right to left
    /// - Parameters:
    ///   - diffResult: The diff result containing all differences
    ///   - createBackup: Whether to create a backup before merging (default: true)
    /// - Returns: MergeResult indicating success/failure and details
    func mergeAllRightToLeft(diffResult: DiffResult, createBackup: Bool = true) throws -> MergeResult {
        guard let destinationURL = diffResult.leftFile else {
            throw MergeError.fileNotFound("Left file not specified")
        }
        
        guard let sourceURL = diffResult.rightFile else {
            throw MergeError.fileNotFound("Right file not specified")
        }
        
        // Create backup before merge if requested
        var backupURL: URL? = nil
        if createBackup && fileManager.fileExists(atPath: destinationURL.path) {
            do {
                let backupInfo = try backupService.createBackup(of: destinationURL)
                backupURL = backupInfo.backupURL
            } catch {
                throw MergeError.backupError(error.localizedDescription)
            }
        }
        
        // Simply copy the entire right file to left
        let sourceContent: String
        do {
            sourceContent = try String(contentsOf: sourceURL, encoding: .utf8)
        } catch {
            throw MergeError.readError(error.localizedDescription)
        }
        
        do {
            try sourceContent.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            throw MergeError.writeError(error.localizedDescription)
        }
        
        return MergeResult(
            success: true,
            mergedContent: sourceContent,
            changesApplied: diffResult.chunks.count,
            message: "Successfully merged all \(diffResult.chunks.count) chunks from right to left",
            backupURL: backupURL
        )
    }
    
    // MARK: - Selective Merge Operations
    
    /// Merge selected chunks from source to destination
    /// - Parameters:
    ///   - chunkIndices: Array of chunk indices to merge (sorted in ascending order)
    ///   - diffResult: The diff result containing all chunks
    ///   - direction: The merge direction
    ///   - createBackup: Whether to create a backup before merging (default: true)
    /// - Returns: MergeResult indicating success/failure and details
    func mergeSelectedChunks(
        chunkIndices: [Int],
        diffResult: DiffResult,
        direction: MergeDirection,
        createBackup: Bool = true
    ) throws -> MergeResult {
        guard !chunkIndices.isEmpty else {
            return MergeResult(
                success: true,
                mergedContent: "",
                changesApplied: 0,
                message: "No chunks selected for merge"
            )
        }
        
        // Validate all indices
        for index in chunkIndices {
            guard index >= 0 && index < diffResult.chunks.count else {
                throw MergeError.invalidChunkIndex
            }
        }
        
        // Determine destination based on direction
        let destinationURL: URL?
        switch direction {
        case .leftToRight:
            destinationURL = diffResult.rightFile
        case .rightToLeft:
            destinationURL = diffResult.leftFile
        }
        
        guard let destURL = destinationURL else {
            throw MergeError.fileNotFound("Destination file not specified")
        }
        
        // Create backup before merge if requested
        var backupURL: URL? = nil
        if createBackup {
            do {
                let backupInfo = try backupService.createBackup(of: destURL)
                backupURL = backupInfo.backupURL
            } catch {
                throw MergeError.backupError(error.localizedDescription)
            }
        }
        
        // Read destination file
        var currentContent: String
        do {
            currentContent = try String(contentsOf: destURL, encoding: .utf8)
        } catch {
            throw MergeError.readError(error.localizedDescription)
        }
        
        // Sort chunk indices in descending order to apply from bottom to top
        // This prevents line number shifts from affecting subsequent merges
        let sortedIndices = chunkIndices.sorted(by: >)
        
        var mergedLines = currentContent.components(separatedBy: .newlines)
        
        for chunkIndex in sortedIndices {
            let chunk = diffResult.chunks[chunkIndex]
            mergedLines = mergeChunk(
                chunk: chunk,
                destinationLines: mergedLines,
                direction: direction
            )
        }
        
        let mergedContent = mergedLines.joined(separator: "\n")
        
        // Write to destination
        do {
            try mergedContent.write(to: destURL, atomically: true, encoding: .utf8)
        } catch {
            throw MergeError.writeError(error.localizedDescription)
        }
        
        return MergeResult(
            success: true,
            mergedContent: mergedContent,
            changesApplied: chunkIndices.count,
            message: "Successfully merged \(chunkIndices.count) selected chunks",
            backupURL: backupURL
        )
    }
    
    // MARK: - Content Preview
    
    /// Preview the result of merging a chunk without actually writing to file
    /// - Parameters:
    ///   - chunkIndex: Index of the chunk to merge
    ///   - diffResult: The diff result containing all chunks
    ///   - direction: The merge direction
    /// - Returns: The preview content as a string
    func previewChunkMerge(
        chunkIndex: Int,
        diffResult: DiffResult,
        direction: MergeDirection
    ) throws -> String {
        guard chunkIndex >= 0 && chunkIndex < diffResult.chunks.count else {
            throw MergeError.invalidChunkIndex
        }
        
        let chunk = diffResult.chunks[chunkIndex]
        
        // Determine destination based on direction
        let destinationURL: URL?
        switch direction {
        case .leftToRight:
            destinationURL = diffResult.rightFile
        case .rightToLeft:
            destinationURL = diffResult.leftFile
        }
        
        guard let destURL = destinationURL else {
            throw MergeError.fileNotFound("Destination file not specified")
        }
        
        // Read destination file
        let destinationContent: String
        do {
            destinationContent = try String(contentsOf: destURL, encoding: .utf8)
        } catch {
            throw MergeError.readError(error.localizedDescription)
        }
        
        let destinationLines = destinationContent.components(separatedBy: .newlines)
        
        let mergedLines = mergeChunk(
            chunk: chunk,
            destinationLines: destinationLines,
            direction: direction
        )
        
        return mergedLines.joined(separator: "\n")
    }
    
    // MARK: - Backup Restore Operations
    
    /// Restore a file from a backup
    /// - Parameters:
    ///   - backupURL: URL of the backup file
    ///   - originalURL: URL of the file to restore
    func restoreFromBackup(backupURL: URL, to originalURL: URL) throws {
        do {
            try backupService.restore(from: backupURL, to: originalURL)
        } catch {
            throw MergeError.backupError("Restore failed: \(error.localizedDescription)")
        }
    }
    
    /// Get the most recent backup for a file
    /// - Parameter fileURL: URL of the file
    /// - Returns: URL of the most recent backup, or nil if none exists
    func mostRecentBackup(for fileURL: URL) -> URL? {
        return backupService.mostRecentBackup(for: fileURL)
    }
    
    /// List all backups for a file
    /// - Parameter fileURL: URL of the file
    /// - Returns: Array of backup URLs sorted by date (newest first)
    func listBackups(for fileURL: URL) -> [URL] {
        return backupService.listBackups(for: fileURL)
    }
    
    /// Clean up old backups, keeping only the specified number of most recent backups
    /// - Parameters:
    ///   - fileURL: URL of the file
    ///   - keepCount: Number of backups to keep (default: 5)
    func cleanupOldBackups(for fileURL: URL, keepCount: Int = 5) throws {
        do {
            try backupService.cleanupOldBackups(for: fileURL, keepCount: keepCount)
        } catch {
            throw MergeError.backupError("Cleanup failed: \(error.localizedDescription)")
        }
    }
}

/// Direction of merge operation
enum MergeDirection {
    case leftToRight
    case rightToLeft
    
    var description: String {
        switch self {
        case .leftToRight:
            return "Left → Right"
        case .rightToLeft:
            return "Right → Left"
        }
    }
}

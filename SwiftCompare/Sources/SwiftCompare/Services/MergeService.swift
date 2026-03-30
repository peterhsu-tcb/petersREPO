import Foundation

/// Service for merging differences between files
class MergeService {
    private let fileManager = FileManager.default
    
    /// Errors that can occur during merge operations
    enum MergeError: Error, LocalizedError {
        case fileNotFound(String)
        case readError(String)
        case writeError(String)
        case invalidChunkIndex
        case mergeConflict(String)
        
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
            }
        }
    }
    
    /// Result of a merge operation
    struct MergeResult {
        let success: Bool
        let mergedContent: String
        let changesApplied: Int
        let message: String
    }
    
    // MARK: - Chunk-level Merge Operations
    
    /// Merge a specific chunk from source to destination
    /// - Parameters:
    ///   - chunk: The diff chunk to merge
    ///   - sourceLines: Lines from the source file
    ///   - destinationLines: Lines from the destination file
    ///   - direction: The merge direction (.leftToRight or .rightToLeft)
    /// - Returns: The merged lines array
    func mergeChunk(
        chunk: DiffChunk,
        sourceLines: [String],
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
    /// - Returns: MergeResult indicating success/failure and details
    func mergeChunkAtIndex(
        chunkIndex: Int,
        diffResult: DiffResult,
        direction: MergeDirection
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
        
        // Read destination file
        let destinationContent: String
        do {
            destinationContent = try String(contentsOf: destURL, encoding: .utf8)
        } catch {
            throw MergeError.readError(error.localizedDescription)
        }
        
        let destinationLines = destinationContent.components(separatedBy: .newlines)
        
        // For source, we use the chunk's lines directly
        let mergedLines = mergeChunk(
            chunk: chunk,
            sourceLines: [], // Not needed as chunk contains the lines
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
            message: "Successfully merged chunk \(chunkIndex + 1)"
        )
    }
    
    // MARK: - Full File Merge Operations
    
    /// Merge all differences from left to right
    /// - Parameter diffResult: The diff result containing all differences
    /// - Returns: MergeResult indicating success/failure and details
    func mergeAllLeftToRight(diffResult: DiffResult) throws -> MergeResult {
        guard let destinationURL = diffResult.rightFile else {
            throw MergeError.fileNotFound("Right file not specified")
        }
        
        guard let sourceURL = diffResult.leftFile else {
            throw MergeError.fileNotFound("Left file not specified")
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
            message: "Successfully merged all \(diffResult.chunks.count) chunks from left to right"
        )
    }
    
    /// Merge all differences from right to left
    /// - Parameter diffResult: The diff result containing all differences
    /// - Returns: MergeResult indicating success/failure and details
    func mergeAllRightToLeft(diffResult: DiffResult) throws -> MergeResult {
        guard let destinationURL = diffResult.leftFile else {
            throw MergeError.fileNotFound("Left file not specified")
        }
        
        guard let sourceURL = diffResult.rightFile else {
            throw MergeError.fileNotFound("Right file not specified")
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
            message: "Successfully merged all \(diffResult.chunks.count) chunks from right to left"
        )
    }
    
    // MARK: - Selective Merge Operations
    
    /// Merge selected chunks from source to destination
    /// - Parameters:
    ///   - chunkIndices: Array of chunk indices to merge (sorted in ascending order)
    ///   - diffResult: The diff result containing all chunks
    ///   - direction: The merge direction
    /// - Returns: MergeResult indicating success/failure and details
    func mergeSelectedChunks(
        chunkIndices: [Int],
        diffResult: DiffResult,
        direction: MergeDirection
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
                sourceLines: [],
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
            message: "Successfully merged \(chunkIndices.count) selected chunks"
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
            sourceLines: [],
            destinationLines: destinationLines,
            direction: direction
        )
        
        return mergedLines.joined(separator: "\n")
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

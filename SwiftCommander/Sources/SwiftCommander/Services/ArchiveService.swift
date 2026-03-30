import Foundation
import Compression

/// Service for handling archive files (ZIP)
class ArchiveService {
    
    private let fileManager = FileManager.default
    
    /// Archive error types
    enum ArchiveError: Error, LocalizedError {
        case fileNotFound(String)
        case notAnArchive(String)
        case extractionFailed(String)
        case compressionFailed(String)
        case invalidArchive(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .notAnArchive(let path):
                return "Not a valid archive: \(path)"
            case .extractionFailed(let message):
                return "Extraction failed: \(message)"
            case .compressionFailed(let message):
                return "Compression failed: \(message)"
            case .invalidArchive(let message):
                return "Invalid archive: \(message)"
            }
        }
    }
    
    /// Archive item representing a file within an archive
    struct ArchiveItem {
        let name: String
        let path: String
        let isDirectory: Bool
        let compressedSize: Int64
        let uncompressedSize: Int64
        let modificationDate: Date?
    }
    
    /// Supported archive formats
    enum ArchiveFormat: String, CaseIterable {
        case zip
        case tar
        case tarGz = "tar.gz"
        case tgz
        
        static func from(url: URL) -> ArchiveFormat? {
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "zip":
                return .zip
            case "tar":
                return .tar
            case "gz", "tgz":
                // Check if it's .tar.gz
                if url.deletingPathExtension().pathExtension.lowercased() == "tar" {
                    return .tarGz
                }
                return ext == "tgz" ? .tgz : nil
            default:
                return nil
            }
        }
    }
    
    // MARK: - Archive Detection
    
    /// Check if a file is an archive
    func isArchive(at url: URL) -> Bool {
        return ArchiveFormat.from(url: url) != nil
    }
    
    /// Get archive format
    func archiveFormat(at url: URL) -> ArchiveFormat? {
        return ArchiveFormat.from(url: url)
    }
    
    // MARK: - ZIP Operations
    
    /// List contents of a ZIP archive
    func listZipContents(at url: URL) throws -> [ArchiveItem] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ArchiveError.fileNotFound(url.path)
        }
        
        // Use the built-in Process to run `unzip -l` to list contents
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-l", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ArchiveError.invalidArchive(error.localizedDescription)
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ArchiveError.invalidArchive("Could not read archive listing")
        }
        
        return parseUnzipListOutput(output)
    }
    
    /// Extract ZIP archive to destination
    func extractZip(at url: URL, to destination: URL, progress: ((String, Double) -> Void)? = nil) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ArchiveError.fileNotFound(url.path)
        }
        
        // Create destination directory if needed
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", destination.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ArchiveError.extractionFailed(error.localizedDescription)
        }
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.extractionFailed(errorOutput)
        }
    }
    
    /// Create ZIP archive from files
    func createZip(from urls: [URL], to destination: URL, progress: ((String, Double) -> Void)? = nil) throws {
        guard !urls.isEmpty else {
            throw ArchiveError.compressionFailed("No files to compress")
        }
        
        // Remove existing archive if present
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        // Build arguments
        var args = ["-r", destination.path]
        
        // Get common base path
        let basePath = urls[0].deletingLastPathComponent().path
        process.currentDirectoryURL = URL(fileURLWithPath: basePath)
        
        // Add relative paths
        for url in urls {
            let relativePath = url.lastPathComponent
            args.append(relativePath)
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ArchiveError.compressionFailed(error.localizedDescription)
        }
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.compressionFailed(errorOutput)
        }
    }
    
    /// Add files to existing ZIP archive
    func addToZip(archive: URL, files: [URL]) throws {
        guard fileManager.fileExists(atPath: archive.path) else {
            throw ArchiveError.fileNotFound(archive.path)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        var args = ["-r", archive.path]
        for file in files {
            args.append(file.path)
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ArchiveError.compressionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - TAR Operations
    
    /// Extract TAR archive
    func extractTar(at url: URL, to destination: URL, compressed: Bool = false) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ArchiveError.fileNotFound(url.path)
        }
        
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        var args = ["-x"]
        if compressed {
            args.append("-z")
        }
        args.append(contentsOf: ["-f", url.path, "-C", destination.path])
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ArchiveError.extractionFailed(error.localizedDescription)
        }
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.extractionFailed(errorOutput)
        }
    }
    
    /// Create TAR archive
    func createTar(from urls: [URL], to destination: URL, compress: Bool = false) throws {
        guard !urls.isEmpty else {
            throw ArchiveError.compressionFailed("No files to compress")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        var args = ["-c"]
        if compress {
            args.append("-z")
        }
        args.append(contentsOf: ["-f", destination.path])
        
        // Get common base path
        let basePath = urls[0].deletingLastPathComponent().path
        process.currentDirectoryURL = URL(fileURLWithPath: basePath)
        
        for url in urls {
            args.append(url.lastPathComponent)
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ArchiveError.compressionFailed(error.localizedDescription)
        }
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.compressionFailed(errorOutput)
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseUnzipListOutput(_ output: String) -> [ArchiveItem] {
        var items: [ArchiveItem] = []
        let lines = output.components(separatedBy: "\n")
        
        // Skip header lines and parse content
        // Format: Length Date Time Name
        var inContent = false
        
        for line in lines {
            if line.contains("--------") {
                inContent = !inContent
                continue
            }
            
            if inContent && !line.isEmpty {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let components = trimmed.components(separatedBy: CharacterSet.whitespaces)
                    .filter { !$0.isEmpty }
                
                if components.count >= 4 {
                    let size = Int64(components[0]) ?? 0
                    let name = components[3...].joined(separator: " ")
                    let isDirectory = name.hasSuffix("/")
                    
                    items.append(ArchiveItem(
                        name: isDirectory ? String(name.dropLast()) : name,
                        path: name,
                        isDirectory: isDirectory,
                        compressedSize: size,
                        uncompressedSize: size,
                        modificationDate: nil
                    ))
                }
            }
        }
        
        return items
    }
}

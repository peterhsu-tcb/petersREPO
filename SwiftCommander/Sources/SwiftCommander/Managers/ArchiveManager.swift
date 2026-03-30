import Foundation

/// Manages archive operations (ZIP, TAR, GZIP, BZIP2)
class ArchiveManager {
    static let shared = ArchiveManager()
    
    private init() {}
    
    /// Supported archive types for creation
    enum ArchiveType: String, CaseIterable {
        case zip = "zip"
        case tar = "tar"
        case tarGz = "tar.gz"
        case tarBz2 = "tar.bz2"
        
        var displayName: String {
            switch self {
            case .zip: return "ZIP"
            case .tar: return "TAR"
            case .tarGz: return "TAR.GZ"
            case .tarBz2: return "TAR.BZ2"
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
    }
    
    /// Create an archive from files/folders
    func createArchive(
        type: ArchiveType,
        from sources: [URL],
        to destination: URL
    ) async throws {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = sources.first?.deletingLastPathComponent()
        
        let sourceNames = sources.map { $0.lastPathComponent }
        
        switch type {
        case .zip:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-r", destination.path] + sourceNames
            
        case .tar:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-cvf", destination.path] + sourceNames
            
        case .tarGz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-czvf", destination.path] + sourceNames
            
        case .tarBz2:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-cjvf", destination.path] + sourceNames
        }
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.creationFailed(output)
        }
    }
    
    /// Extract an archive to a destination folder
    func extractArchive(
        from source: URL,
        to destination: URL
    ) async throws {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = destination
        
        let ext = source.pathExtension.lowercased()
        let fullPath = source.path.lowercased()
        
        if ext == "zip" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", source.path]
        } else if fullPath.hasSuffix(".tar.gz") || fullPath.hasSuffix(".tgz") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzvf", source.path]
        } else if fullPath.hasSuffix(".tar.bz2") || fullPath.hasSuffix(".tbz2") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xjvf", source.path]
        } else if ext == "tar" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xvf", source.path]
        } else if ext == "gz" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
            process.arguments = ["-c", source.path]
            // Write output to file
            let outputURL = destination.appendingPathComponent(source.deletingPathExtension().lastPathComponent)
            process.standardOutput = try FileHandle(forWritingTo: outputURL)
        } else if ext == "bz2" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/bunzip2")
            process.arguments = ["-c", source.path]
            let outputURL = destination.appendingPathComponent(source.deletingPathExtension().lastPathComponent)
            process.standardOutput = try FileHandle(forWritingTo: outputURL)
        } else {
            throw ArchiveError.unsupportedFormat(ext)
        }
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.extractionFailed(output)
        }
    }
    
    /// List contents of an archive
    func listArchiveContents(at url: URL) async throws -> [String] {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        
        let ext = url.pathExtension.lowercased()
        let fullPath = url.path.lowercased()
        
        if ext == "zip" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-l", url.path]
        } else if fullPath.hasSuffix(".tar.gz") || fullPath.hasSuffix(".tgz") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-tzvf", url.path]
        } else if fullPath.hasSuffix(".tar.bz2") || fullPath.hasSuffix(".tbz2") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-tjvf", url.path]
        } else if ext == "tar" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-tvf", url.path]
        } else {
            throw ArchiveError.unsupportedFormat(ext)
        }
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw ArchiveError.listingFailed(output)
        }
        
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    /// Check if a file is a supported archive
    func isArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supportedExtensions = ["zip", "tar", "gz", "tgz", "bz2", "tbz2"]
        return supportedExtensions.contains(ext) || 
               url.path.lowercased().hasSuffix(".tar.gz") ||
               url.path.lowercased().hasSuffix(".tar.bz2")
    }
}

/// Archive operation errors
enum ArchiveError: LocalizedError {
    case creationFailed(String)
    case extractionFailed(String)
    case listingFailed(String)
    case unsupportedFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create archive: \(message)"
        case .extractionFailed(let message):
            return "Failed to extract archive: \(message)"
        case .listingFailed(let message):
            return "Failed to list archive contents: \(message)"
        case .unsupportedFormat(let format):
            return "Unsupported archive format: \(format)"
        }
    }
}

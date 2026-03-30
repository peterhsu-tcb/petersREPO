import Foundation

/// Service for creating and managing file backups
class BackupService {
    private let fileManager = FileManager.default
    
    /// Default backup directory name
    private let backupDirectoryName = ".swiftcommander_backups"
    
    /// Errors that can occur during backup operations
    enum BackupError: Error, LocalizedError {
        case fileNotFound(String)
        case backupFailed(String)
        case restoreFailed(String)
        case directoryCreationFailed(String)
        case backupNotFound(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .backupFailed(let message):
                return "Backup failed: \(message)"
            case .restoreFailed(let message):
                return "Restore failed: \(message)"
            case .directoryCreationFailed(let message):
                return "Failed to create backup directory: \(message)"
            case .backupNotFound(let path):
                return "Backup not found: \(path)"
            }
        }
    }
    
    /// Information about a created backup
    struct BackupInfo {
        let originalURL: URL
        let backupURL: URL
        let timestamp: Date
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            return formatter.string(from: timestamp)
        }
    }
    
    // MARK: - Backup Directory Management
    
    /// Get the backup directory for a given file
    private func backupDirectory(for fileURL: URL) -> URL {
        let parentDirectory = fileURL.deletingLastPathComponent()
        return parentDirectory.appendingPathComponent(backupDirectoryName, isDirectory: true)
    }
    
    /// Ensure the backup directory exists
    private func ensureBackupDirectory(for fileURL: URL) throws -> URL {
        let backupDir = backupDirectory(for: fileURL)
        
        if !fileManager.fileExists(atPath: backupDir.path) {
            do {
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            } catch {
                throw BackupError.directoryCreationFailed(error.localizedDescription)
            }
        }
        
        return backupDir
    }
    
    // MARK: - Backup Operations
    
    /// Create a backup of the specified file
    func createBackup(of fileURL: URL) throws -> BackupInfo {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw BackupError.fileNotFound(fileURL.path)
        }
        
        let timestamp = Date()
        let backupDir = try ensureBackupDirectory(for: fileURL)
        
        // Create backup filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestampString = formatter.string(from: timestamp)
        
        let originalFileName = fileURL.lastPathComponent
        let backupFileName = "\(originalFileName).\(timestampString).backup"
        let backupURL = backupDir.appendingPathComponent(backupFileName)
        
        do {
            // If a backup with the same name exists (same second), remove it first
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            
            try fileManager.copyItem(at: fileURL, to: backupURL)
        } catch {
            throw BackupError.backupFailed(error.localizedDescription)
        }
        
        return BackupInfo(
            originalURL: fileURL,
            backupURL: backupURL,
            timestamp: timestamp
        )
    }
    
    // MARK: - Restore Operations
    
    /// Restore a file from its backup
    func restore(from backupInfo: BackupInfo) throws {
        guard fileManager.fileExists(atPath: backupInfo.backupURL.path) else {
            throw BackupError.backupNotFound(backupInfo.backupURL.path)
        }
        
        do {
            // Remove the current file if it exists
            if fileManager.fileExists(atPath: backupInfo.originalURL.path) {
                try fileManager.removeItem(at: backupInfo.originalURL)
            }
            
            // Copy backup to original location
            try fileManager.copyItem(at: backupInfo.backupURL, to: backupInfo.originalURL)
        } catch {
            throw BackupError.restoreFailed(error.localizedDescription)
        }
    }
    
    /// Restore a file from a specific backup URL
    func restore(from backupURL: URL, to originalURL: URL) throws {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw BackupError.backupNotFound(backupURL.path)
        }
        
        do {
            // Remove the current file if it exists
            if fileManager.fileExists(atPath: originalURL.path) {
                try fileManager.removeItem(at: originalURL)
            }
            
            // Copy backup to original location
            try fileManager.copyItem(at: backupURL, to: originalURL)
        } catch {
            throw BackupError.restoreFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Backup Management
    
    /// List all backups for a specific file
    func listBackups(for fileURL: URL) -> [URL] {
        let backupDir = backupDirectory(for: fileURL)
        let fileName = fileURL.lastPathComponent
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        // Filter to only backups of this specific file
        let backups = contents.filter { url in
            url.lastPathComponent.hasPrefix(fileName) && url.lastPathComponent.hasSuffix(".backup")
        }
        
        // Sort by creation date (newest first)
        return backups.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    /// Get the most recent backup for a file
    func mostRecentBackup(for fileURL: URL) -> URL? {
        return listBackups(for: fileURL).first
    }
    
    /// Delete a specific backup
    func deleteBackup(at backupURL: URL) throws {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw BackupError.backupNotFound(backupURL.path)
        }
        
        try fileManager.removeItem(at: backupURL)
    }
    
    /// Delete all backups for a specific file
    func deleteAllBackups(for fileURL: URL) throws {
        let backups = listBackups(for: fileURL)
        for backupURL in backups {
            try fileManager.removeItem(at: backupURL)
        }
    }
    
    /// Clean up old backups, keeping only the specified number of most recent backups
    func cleanupOldBackups(for fileURL: URL, keepCount: Int = 5) throws {
        let backups = listBackups(for: fileURL)
        
        if backups.count > keepCount {
            let backupsToDelete = backups.suffix(from: keepCount)
            for backupURL in backupsToDelete {
                try fileManager.removeItem(at: backupURL)
            }
        }
    }
}

import XCTest
@testable import SwiftCompare

final class BackupServiceTests: XCTestCase {
    var backupService: BackupService!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        backupService = BackupService()
        
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempDirectory)
        backupService = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestFile(named name: String, content: String) -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func readFile(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
    
    // MARK: - Backup Creation Tests
    
    func testCreateBackup() throws {
        // Create a test file
        let content = "Original content"
        let fileURL = createTestFile(named: "test.txt", content: content)
        
        // Create backup
        let backupInfo = try backupService.createBackup(of: fileURL)
        
        // Verify backup was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupInfo.backupURL.path))
        
        // Verify backup content matches original
        let backupContent = readFile(at: backupInfo.backupURL)
        XCTAssertEqual(backupContent, content)
        
        // Verify backup info
        XCTAssertEqual(backupInfo.originalURL, fileURL)
        XCTAssertTrue(backupInfo.backupURL.lastPathComponent.contains("test.txt"))
        XCTAssertTrue(backupInfo.backupURL.lastPathComponent.hasSuffix(".backup"))
    }
    
    func testCreateBackupOfNonexistentFile() {
        let nonexistentURL = tempDirectory.appendingPathComponent("nonexistent.txt")
        
        XCTAssertThrowsError(try backupService.createBackup(of: nonexistentURL)) { error in
            if let backupError = error as? BackupService.BackupError {
                XCTAssertTrue(backupError.localizedDescription.contains("File not found"))
            } else {
                XCTFail("Expected BackupError.fileNotFound")
            }
        }
    }
    
    // MARK: - Restore Tests
    
    func testRestoreFromBackup() throws {
        // Create a test file and backup
        let originalContent = "Original content"
        let fileURL = createTestFile(named: "test.txt", content: originalContent)
        let backupInfo = try backupService.createBackup(of: fileURL)
        
        // Modify the original file
        let modifiedContent = "Modified content"
        try modifiedContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Verify file was modified
        XCTAssertEqual(readFile(at: fileURL), modifiedContent)
        
        // Restore from backup
        try backupService.restore(from: backupInfo)
        
        // Verify file was restored
        XCTAssertEqual(readFile(at: fileURL), originalContent)
    }
    
    func testRestoreFromURL() throws {
        // Create a test file and backup
        let originalContent = "Original content"
        let fileURL = createTestFile(named: "test.txt", content: originalContent)
        let backupInfo = try backupService.createBackup(of: fileURL)
        
        // Modify the original file
        let modifiedContent = "Modified content"
        try modifiedContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Restore from backup URL
        try backupService.restore(from: backupInfo.backupURL, to: fileURL)
        
        // Verify file was restored
        XCTAssertEqual(readFile(at: fileURL), originalContent)
    }
    
    func testRestoreFromNonexistentBackup() {
        let nonexistentBackupURL = tempDirectory.appendingPathComponent("nonexistent.backup")
        let originalURL = tempDirectory.appendingPathComponent("test.txt")
        
        XCTAssertThrowsError(try backupService.restore(from: nonexistentBackupURL, to: originalURL)) { error in
            XCTAssertTrue(error is BackupService.BackupError)
        }
    }
    
    // MARK: - List Backups Tests
    
    func testListBackups() throws {
        // Create a test file
        let fileURL = createTestFile(named: "test.txt", content: "Content")
        
        // Create multiple backups with small delays
        _ = try backupService.createBackup(of: fileURL)
        Thread.sleep(forTimeInterval: 1.1) // Wait for different timestamp
        _ = try backupService.createBackup(of: fileURL)
        
        // List backups
        let backups = backupService.listBackups(for: fileURL)
        
        // Verify we have at least 2 backups
        XCTAssertGreaterThanOrEqual(backups.count, 2)
        
        // Verify backups are for the correct file
        for backup in backups {
            XCTAssertTrue(backup.lastPathComponent.contains("test.txt"))
        }
    }
    
    func testMostRecentBackup() throws {
        // Create a test file
        let fileURL = createTestFile(named: "test.txt", content: "Content 1")
        
        // Create first backup
        _ = try backupService.createBackup(of: fileURL)
        Thread.sleep(forTimeInterval: 1.1)
        
        // Modify file and create second backup
        try "Content 2".write(to: fileURL, atomically: true, encoding: .utf8)
        let secondBackup = try backupService.createBackup(of: fileURL)
        
        // Get most recent backup
        let mostRecent = backupService.mostRecentBackup(for: fileURL)
        
        // Verify it's the second backup (most recent)
        XCTAssertNotNil(mostRecent)
        XCTAssertEqual(mostRecent, secondBackup.backupURL)
    }
    
    func testNoBackupsReturnsNil() {
        let fileURL = tempDirectory.appendingPathComponent("nobackups.txt")
        
        XCTAssertNil(backupService.mostRecentBackup(for: fileURL))
        XCTAssertTrue(backupService.listBackups(for: fileURL).isEmpty)
    }
    
    // MARK: - Delete Backup Tests
    
    func testDeleteBackup() throws {
        // Create a test file and backup
        let fileURL = createTestFile(named: "test.txt", content: "Content")
        let backupInfo = try backupService.createBackup(of: fileURL)
        
        // Verify backup exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupInfo.backupURL.path))
        
        // Delete backup
        try backupService.deleteBackup(at: backupInfo.backupURL)
        
        // Verify backup was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupInfo.backupURL.path))
    }
    
    func testDeleteAllBackups() throws {
        // Create a test file
        let fileURL = createTestFile(named: "test.txt", content: "Content")
        
        // Create multiple backups
        _ = try backupService.createBackup(of: fileURL)
        Thread.sleep(forTimeInterval: 1.1)
        _ = try backupService.createBackup(of: fileURL)
        
        // Verify backups exist
        XCTAssertGreaterThan(backupService.listBackups(for: fileURL).count, 0)
        
        // Delete all backups
        try backupService.deleteAllBackups(for: fileURL)
        
        // Verify all backups were deleted
        XCTAssertEqual(backupService.listBackups(for: fileURL).count, 0)
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupOldBackups() throws {
        // Create a test file
        let fileURL = createTestFile(named: "test.txt", content: "Content")
        
        // Create 5 backups
        for i in 1...5 {
            try "\(i)".write(to: fileURL, atomically: true, encoding: .utf8)
            _ = try backupService.createBackup(of: fileURL)
            Thread.sleep(forTimeInterval: 1.1)
        }
        
        // Verify we have 5 backups
        XCTAssertEqual(backupService.listBackups(for: fileURL).count, 5)
        
        // Cleanup keeping only 2
        try backupService.cleanupOldBackups(for: fileURL, keepCount: 2)
        
        // Verify we now have only 2 backups
        XCTAssertEqual(backupService.listBackups(for: fileURL).count, 2)
    }
}

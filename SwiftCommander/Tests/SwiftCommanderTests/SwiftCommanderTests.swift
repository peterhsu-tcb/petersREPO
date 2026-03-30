import XCTest
@testable import SwiftCommander

final class SwiftCommanderTests: XCTestCase {
    
    // MARK: - FileItem Tests
    
    func testFileItemFromURL() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_file_\(UUID().uuidString).txt")
        
        // Create a test file
        FileManager.default.createFile(atPath: testFile.path, contents: "test".data(using: .utf8))
        
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        let fileItem = FileItem.from(url: testFile)
        
        XCTAssertNotNil(fileItem)
        XCTAssertEqual(fileItem?.name, testFile.lastPathComponent)
        XCTAssertFalse(fileItem?.isDirectory ?? true)
        XCTAssertEqual(fileItem?.size, 4) // "test" is 4 bytes
    }
    
    func testFileTypeDetection() {
        XCTAssertEqual(FileType.from(extension: "swift"), .code)
        XCTAssertEqual(FileType.from(extension: "py"), .code)
        XCTAssertEqual(FileType.from(extension: "jpg"), .image)
        XCTAssertEqual(FileType.from(extension: "mp4"), .video)
        XCTAssertEqual(FileType.from(extension: "mp3"), .audio)
        XCTAssertEqual(FileType.from(extension: "zip"), .archive)
        XCTAssertEqual(FileType.from(extension: "pdf"), .pdf)
        XCTAssertEqual(FileType.from(extension: "txt"), .text)
        XCTAssertEqual(FileType.from(extension: "unknown"), .other)
    }
    
    func testFilePermissions() {
        let permissions = FilePermissions(posix: 0o755)
        
        XCTAssertTrue(permissions.owner.read)
        XCTAssertTrue(permissions.owner.write)
        XCTAssertTrue(permissions.owner.execute)
        XCTAssertTrue(permissions.group.read)
        XCTAssertFalse(permissions.group.write)
        XCTAssertTrue(permissions.group.execute)
        XCTAssertTrue(permissions.others.read)
        XCTAssertFalse(permissions.others.write)
        XCTAssertTrue(permissions.others.execute)
        
        XCTAssertEqual(permissions.displayString, "rwxr-xr-x")
    }
    
    func testSortOrder() {
        let file1 = FileItem(
            url: URL(fileURLWithPath: "/test/aaa.txt"),
            isDirectory: false,
            size: 100,
            modificationDate: Date(),
            creationDate: Date(),
            isHidden: false,
            isSymbolicLink: false,
            permissions: FilePermissions(posix: 0o644)
        )
        
        let file2 = FileItem(
            url: URL(fileURLWithPath: "/test/zzz.txt"),
            isDirectory: false,
            size: 200,
            modificationDate: Date().addingTimeInterval(3600),
            creationDate: Date(),
            isHidden: false,
            isSymbolicLink: false,
            permissions: FilePermissions(posix: 0o644)
        )
        
        // Name ascending
        XCTAssertTrue(SortOrder.nameAscending.comparator(file1, file2))
        XCTAssertFalse(SortOrder.nameAscending.comparator(file2, file1))
        
        // Name descending
        XCTAssertFalse(SortOrder.nameDescending.comparator(file1, file2))
        XCTAssertTrue(SortOrder.nameDescending.comparator(file2, file1))
        
        // Size ascending
        XCTAssertTrue(SortOrder.sizeAscending.comparator(file1, file2))
        XCTAssertFalse(SortOrder.sizeAscending.comparator(file2, file1))
    }
    
    // MARK: - PanelState Tests
    
    func testPanelStateInitialization() {
        let panel = PanelState(side: .left)
        
        XCTAssertEqual(panel.side, .left)
        XCTAssertTrue(panel.files.isEmpty)
        XCTAssertTrue(panel.selectedFiles.isEmpty)
        XCTAssertEqual(panel.sortOrder, .nameAscending)
        XCTAssertFalse(panel.showHiddenFiles)
        XCTAssertTrue(panel.filterText.isEmpty)
    }
    
    func testPanelStateNavigation() {
        let panel = PanelState(side: .left, initialDirectory: FileManager.default.homeDirectoryForCurrentUser)
        
        let documentsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        
        panel.navigateTo(documentsURL)
        
        XCTAssertEqual(panel.currentDirectory, documentsURL)
        XCTAssertTrue(panel.canNavigateBack)
        XCTAssertFalse(panel.canNavigateForward)
        
        panel.navigateBack()
        
        XCTAssertEqual(panel.currentDirectory, FileManager.default.homeDirectoryForCurrentUser)
        XCTAssertFalse(panel.canNavigateBack)
        XCTAssertTrue(panel.canNavigateForward)
    }
    
    func testPanelStateSelection() {
        let panel = PanelState(side: .left)
        
        let fileId1 = UUID()
        let fileId2 = UUID()
        let fileId3 = UUID()
        
        // Single selection
        panel.selectSingle(fileId1)
        XCTAssertEqual(panel.selectedFiles, [fileId1])
        
        // Add to selection
        panel.addToSelection(fileId2)
        XCTAssertEqual(panel.selectedFiles, [fileId1, fileId2])
        
        // Toggle selection
        panel.toggleSelection(fileId1)
        XCTAssertEqual(panel.selectedFiles, [fileId2])
        
        // Clear selection
        panel.clearSelection()
        XCTAssertTrue(panel.selectedFiles.isEmpty)
    }
    
    // MARK: - BookmarkItem Tests
    
    func testBookmarkItem() {
        let bookmark = BookmarkItem(
            name: "Test",
            path: "/Users/test",
            icon: "folder.fill"
        )
        
        XCTAssertEqual(bookmark.name, "Test")
        XCTAssertEqual(bookmark.path, "/Users/test")
        XCTAssertEqual(bookmark.url.path, "/Users/test")
    }
    
    func testBookmarkManager() {
        let manager = BookmarkManager()
        
        // Add bookmark
        let bookmark = BookmarkItem(name: "Test", path: "/tmp/test")
        manager.addBookmark(bookmark)
        
        XCTAssertTrue(manager.isBookmarked(path: "/tmp/test"))
        
        // Remove bookmark
        manager.removeBookmark(bookmark)
        
        XCTAssertFalse(manager.isBookmarked(path: "/tmp/test"))
    }
    
    // MARK: - FileOperationsService Tests
    
    func testFileOperationsServiceListDirectory() throws {
        let service = FileOperationsService()
        let tempDir = FileManager.default.temporaryDirectory
        
        let items = try service.listDirectory(at: tempDir)
        
        // Temp directory should exist and be listable
        XCTAssertNotNil(items)
    }
    
    func testFileOperationsServiceCreateDirectory() throws {
        let service = FileOperationsService()
        let tempDir = FileManager.default.temporaryDirectory
        let newDirName = "test_dir_\(UUID().uuidString)"
        
        let newDirURL = try service.createDirectory(at: tempDir, named: newDirName)
        
        defer {
            try? FileManager.default.removeItem(at: newDirURL)
        }
        
        XCTAssertTrue(service.exists(at: newDirURL))
        XCTAssertTrue(service.isDirectory(at: newDirURL))
    }
    
    func testFileOperationsServiceCopyFile() throws {
        let service = FileOperationsService()
        let tempDir = FileManager.default.temporaryDirectory
        
        // Create source file
        let sourceFile = tempDir.appendingPathComponent("source_\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: sourceFile.path, contents: "test content".data(using: .utf8))
        
        // Create destination directory
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: sourceFile)
            try? FileManager.default.removeItem(at: destDir)
        }
        
        // Copy file
        try service.copy(from: sourceFile, to: destDir)
        
        let copiedFile = destDir.appendingPathComponent(sourceFile.lastPathComponent)
        XCTAssertTrue(service.exists(at: copiedFile))
    }
    
    func testFileOperationsServiceRename() throws {
        let service = FileOperationsService()
        let tempDir = FileManager.default.temporaryDirectory
        
        // Create source file
        let sourceFile = tempDir.appendingPathComponent("rename_test_\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: sourceFile.path, contents: "test".data(using: .utf8))
        
        let newName = "renamed_\(UUID().uuidString).txt"
        let newURL = try service.rename(at: sourceFile, to: newName)
        
        defer {
            try? FileManager.default.removeItem(at: newURL)
        }
        
        XCTAssertFalse(service.exists(at: sourceFile))
        XCTAssertTrue(service.exists(at: newURL))
    }
    
    // MARK: - SearchService Tests
    
    func testSearchServiceQuickSearch() {
        let service = SearchService()
        
        let files: [FileItem] = [
            FileItem(
                url: URL(fileURLWithPath: "/test/document.txt"),
                isDirectory: false,
                size: 100,
                modificationDate: Date(),
                creationDate: Date(),
                isHidden: false,
                isSymbolicLink: false,
                permissions: FilePermissions(posix: 0o644)
            ),
            FileItem(
                url: URL(fileURLWithPath: "/test/image.png"),
                isDirectory: false,
                size: 200,
                modificationDate: Date(),
                creationDate: Date(),
                isHidden: false,
                isSymbolicLink: false,
                permissions: FilePermissions(posix: 0o644)
            ),
            FileItem(
                url: URL(fileURLWithPath: "/test/doc_backup.txt"),
                isDirectory: false,
                size: 150,
                modificationDate: Date(),
                creationDate: Date(),
                isHidden: false,
                isSymbolicLink: false,
                permissions: FilePermissions(posix: 0o644)
            )
        ]
        
        // Search for "doc"
        let results = service.quickSearch(in: files, pattern: "doc")
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "document.txt" })
        XCTAssertTrue(results.contains { $0.name == "doc_backup.txt" })
    }
    
    func testSearchServiceWildcardToRegex() {
        let service = SearchService()
        
        XCTAssertEqual(service.wildcardToRegex("*.txt"), "^.*\\.txt$")
        XCTAssertEqual(service.wildcardToRegex("test?"), "^test.$")
        XCTAssertEqual(service.wildcardToRegex("file.txt"), "^file\\.txt$")
    }
    
    // MARK: - ArchiveService Tests
    
    func testArchiveServiceDetection() {
        let service = ArchiveService()
        
        XCTAssertTrue(service.isArchive(at: URL(fileURLWithPath: "/test/file.zip")))
        XCTAssertTrue(service.isArchive(at: URL(fileURLWithPath: "/test/file.tar")))
        XCTAssertTrue(service.isArchive(at: URL(fileURLWithPath: "/test/file.tar.gz")))
        XCTAssertFalse(service.isArchive(at: URL(fileURLWithPath: "/test/file.txt")))
        XCTAssertFalse(service.isArchive(at: URL(fileURLWithPath: "/test/file.pdf")))
    }
    
    // MARK: - Extension Tests
    
    func testStringExtensions() {
        XCTAssertTrue("validname.txt".isValidFilename)
        XCTAssertFalse("invalid/name.txt".isValidFilename)
        XCTAssertFalse(".".isValidFilename)
        XCTAssertFalse("..".isValidFilename)
        XCTAssertFalse("".isValidFilename)
        
        XCTAssertEqual("file/with:colons".sanitizedFilename, "file_with_colons")
    }
    
    func testInt64Extensions() {
        XCTAssertFalse(Int64(1024).formattedSize.isEmpty)
        XCTAssertFalse(Int64(1024 * 1024).formattedSize.isEmpty)
    }
}

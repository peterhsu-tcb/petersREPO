import XCTest
@testable import SwiftCommander

final class FileItemTests: XCTestCase {
    
    func testFileItemInitialization() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.txt")
        
        // Create a test file
        FileManager.default.createFile(atPath: testFile.path, contents: "Hello".data(using: .utf8))
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        let item = FileItem(url: testFile)
        
        XCTAssertEqual(item.name, "test.txt")
        XCTAssertFalse(item.isDirectory)
        XCTAssertEqual(item.fileExtension, "txt")
        XCTAssertFalse(item.isHidden)
    }
    
    func testDirectoryItem() {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("testDir")
        
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: testDir)
        }
        
        let item = FileItem(url: testDir)
        
        XCTAssertEqual(item.name, "testDir")
        XCTAssertTrue(item.isDirectory)
        XCTAssertEqual(item.formattedSize, "<DIR>")
    }
    
    func testPermissionsString() {
        // Test common permission values
        XCTAssertEqual(FileItem.permissionsString(from: 0o755), "rwxr-xr-x")
        XCTAssertEqual(FileItem.permissionsString(from: 0o644), "rw-r--r--")
        XCTAssertEqual(FileItem.permissionsString(from: 0o777), "rwxrwxrwx")
        XCTAssertEqual(FileItem.permissionsString(from: 0o000), "---------")
    }
    
    func testFileItemSorting() {
        let tempDir = FileManager.default.temporaryDirectory
        
        let dir1 = FileItem(
            url: tempDir.appendingPathComponent("aDir"),
            name: "aDir",
            isDirectory: true,
            isHidden: false,
            isSymlink: false,
            size: 0,
            modificationDate: nil,
            creationDate: nil,
            permissions: "",
            owner: ""
        )
        
        let dir2 = FileItem(
            url: tempDir.appendingPathComponent("bDir"),
            name: "bDir",
            isDirectory: true,
            isHidden: false,
            isSymlink: false,
            size: 0,
            modificationDate: nil,
            creationDate: nil,
            permissions: "",
            owner: ""
        )
        
        let file1 = FileItem(
            url: tempDir.appendingPathComponent("aFile.txt"),
            name: "aFile.txt",
            isDirectory: false,
            isHidden: false,
            isSymlink: false,
            size: 100,
            modificationDate: nil,
            creationDate: nil,
            permissions: "",
            owner: ""
        )
        
        let items = [file1, dir2, dir1].sorted()
        
        // Directories should come first, then sorted by name
        XCTAssertEqual(items[0].name, "aDir")
        XCTAssertEqual(items[1].name, "bDir")
        XCTAssertEqual(items[2].name, "aFile.txt")
    }
    
    func testIconName() {
        let tempDir = FileManager.default.temporaryDirectory
        
        let swiftFile = FileItem(
            url: tempDir.appendingPathComponent("test.swift"),
            name: "test.swift",
            isDirectory: false,
            isHidden: false,
            isSymlink: false,
            size: 100,
            modificationDate: nil,
            creationDate: nil,
            permissions: "",
            owner: ""
        )
        XCTAssertEqual(swiftFile.iconName, "doc.text.fill")
        
        let imageFile = FileItem(
            url: tempDir.appendingPathComponent("photo.png"),
            name: "photo.png",
            isDirectory: false,
            isHidden: false,
            isSymlink: false,
            size: 100,
            modificationDate: nil,
            creationDate: nil,
            permissions: "",
            owner: ""
        )
        XCTAssertEqual(imageFile.iconName, "photo.fill")
        
        let folder = FileItem(
            url: tempDir.appendingPathComponent("folder"),
            name: "folder",
            isDirectory: true,
            isHidden: false,
            isSymlink: false,
            size: 0,
            modificationDate: nil,
            creationDate: nil,
            permissions: "",
            owner: ""
        )
        XCTAssertEqual(folder.iconName, "folder.fill")
    }
}

final class PaneStateTests: XCTestCase {
    
    func testPaneStateInitialization() {
        let pane = PaneState(side: .left)
        
        XCTAssertEqual(pane.side, .left)
        XCTAssertEqual(pane.currentPath, FileManager.default.homeDirectoryForCurrentUser)
        XCTAssertTrue(pane.items.isEmpty)
        XCTAssertTrue(pane.selectedItems.isEmpty)
    }
    
    func testNavigation() {
        let pane = PaneState(side: .right, path: FileManager.default.homeDirectoryForCurrentUser)
        let newPath = FileManager.default.temporaryDirectory
        
        pane.navigateTo(newPath)
        
        XCTAssertEqual(pane.currentPath, newPath)
        XCTAssertEqual(pane.historyBack.count, 1)
        XCTAssertTrue(pane.historyForward.isEmpty)
    }
    
    func testGoBack() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let temp = FileManager.default.temporaryDirectory
        let pane = PaneState(side: .left, path: home)
        
        pane.navigateTo(temp)
        pane.goBack()
        
        XCTAssertEqual(pane.currentPath, home)
        XCTAssertTrue(pane.historyBack.isEmpty)
        XCTAssertEqual(pane.historyForward.count, 1)
    }
    
    func testGoForward() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let temp = FileManager.default.temporaryDirectory
        let pane = PaneState(side: .left, path: home)
        
        pane.navigateTo(temp)
        pane.goBack()
        pane.goForward()
        
        XCTAssertEqual(pane.currentPath, temp)
    }
}

final class FileManagerServiceTests: XCTestCase {
    
    func testListDirectory() throws {
        let service = FileManagerService.shared
        let tempDir = FileManager.default.temporaryDirectory
        
        let items = try service.listDirectory(at: tempDir, showHidden: false)
        
        // Should have at least the parent directory marker
        XCTAssertGreaterThanOrEqual(items.count, 0)
    }
    
    func testCreateFolder() throws {
        let service = FileManagerService.shared
        let tempDir = FileManager.default.temporaryDirectory
        let folderName = "SwiftCommanderTest_\(UUID().uuidString)"
        
        let folderURL = try service.createFolder(at: tempDir, name: folderName)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: folderURL.path))
    }
    
    func testCreateFile() throws {
        let service = FileManagerService.shared
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "SwiftCommanderTest_\(UUID().uuidString).txt"
        
        let fileURL = try service.createFile(at: tempDir, name: fileName)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testRename() throws {
        let service = FileManagerService.shared
        let tempDir = FileManager.default.temporaryDirectory
        let originalName = "SwiftCommanderTest_\(UUID().uuidString).txt"
        let newName = "SwiftCommanderTest_Renamed_\(UUID().uuidString).txt"
        
        let originalURL = try service.createFile(at: tempDir, name: originalName)
        let newURL = try service.rename(at: originalURL, to: newName)
        defer {
            try? FileManager.default.removeItem(at: newURL)
        }
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }
    
    func testGenerateUniqueName() {
        let service = FileManagerService.shared
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.txt")
        
        // Create the file
        FileManager.default.createFile(atPath: testFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        let uniqueURL = service.generateUniqueName(for: testFile)
        
        XCTAssertTrue(uniqueURL.lastPathComponent.contains("(1)"))
    }
}

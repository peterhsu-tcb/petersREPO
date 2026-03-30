import XCTest
@testable import SwiftCompare

final class MergeServiceTests: XCTestCase {
    var mergeService: MergeService!
    var fileComparisonService: FileComparisonService!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        mergeService = MergeService()
        fileComparisonService = FileComparisonService()
        
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempDirectory)
        mergeService = nil
        fileComparisonService = nil
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
    
    // MARK: - Merge All Tests
    
    func testMergeAllLeftToRight() throws {
        // Create test files
        let leftContent = "Line 1\nLine 2\nLine 3"
        let rightContent = "Line 1\nLine 2 Modified\nLine 3"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // Perform merge
        let result = try mergeService.mergeAllLeftToRight(diffResult: diffResult)
        
        // Verify
        XCTAssertTrue(result.success)
        let mergedContent = readFile(at: rightFile)
        XCTAssertEqual(mergedContent, leftContent)
    }
    
    func testMergeAllRightToLeft() throws {
        // Create test files
        let leftContent = "Line 1\nLine 2\nLine 3"
        let rightContent = "Line 1\nLine 2 Modified\nLine 3"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // Perform merge
        let result = try mergeService.mergeAllRightToLeft(diffResult: diffResult)
        
        // Verify
        XCTAssertTrue(result.success)
        let mergedContent = readFile(at: leftFile)
        XCTAssertEqual(mergedContent, rightContent)
    }
    
    // MARK: - Chunk Merge Tests
    
    func testMergeChunkLeftToRight() throws {
        // Create test files with multiple differences
        let leftContent = "Line 1\nLeft Line 2\nLine 3\nLeft Line 4\nLine 5"
        let rightContent = "Line 1\nRight Line 2\nLine 3\nRight Line 4\nLine 5"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // Verify we have chunks
        XCTAssertGreaterThan(diffResult.chunks.count, 0, "Should have at least one chunk")
        
        // Merge first chunk only
        let result = try mergeService.mergeChunkAtIndex(
            chunkIndex: 0,
            diffResult: diffResult,
            direction: .leftToRight
        )
        
        // Verify
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.changesApplied, 1)
    }
    
    func testMergeChunkRightToLeft() throws {
        // Create test files with a difference
        let leftContent = "Line 1\nLeft Line 2\nLine 3"
        let rightContent = "Line 1\nRight Line 2\nLine 3"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // Verify we have chunks
        XCTAssertGreaterThan(diffResult.chunks.count, 0, "Should have at least one chunk")
        
        // Merge first chunk
        let result = try mergeService.mergeChunkAtIndex(
            chunkIndex: 0,
            diffResult: diffResult,
            direction: .rightToLeft
        )
        
        // Verify
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.changesApplied, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testMergeInvalidChunkIndex() {
        // Create test files
        let leftContent = "Line 1\nLine 2"
        let rightContent = "Line 1\nLine 2 Modified"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // Try to merge with invalid index
        XCTAssertThrowsError(try mergeService.mergeChunkAtIndex(
            chunkIndex: 999,
            diffResult: diffResult,
            direction: .leftToRight
        )) { error in
            if let mergeError = error as? MergeService.MergeError {
                XCTAssertEqual(mergeError.localizedDescription, "Invalid chunk index specified")
            } else {
                XCTFail("Expected MergeError.invalidChunkIndex")
            }
        }
    }
    
    func testMergeWithNoDestinationFile() {
        // Create diff result with nil files
        let diffResult = DiffResult(
            leftFile: nil,
            rightFile: nil,
            chunks: [],
            leftLines: [],
            rightLines: [],
            isIdentical: true
        )
        
        // Try to merge
        XCTAssertThrowsError(try mergeService.mergeAllLeftToRight(diffResult: diffResult)) { error in
            XCTAssertTrue(error is MergeService.MergeError)
        }
    }
    
    // MARK: - Selected Chunks Tests
    
    func testMergeSelectedChunks() throws {
        // Create test files with multiple differences
        let leftContent = "Line 1\nLeft A\nLine 3\nLeft B\nLine 5"
        let rightContent = "Line 1\nRight A\nLine 3\nRight B\nLine 5"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // If we have multiple chunks, test selecting specific ones
        if diffResult.chunks.count >= 1 {
            let result = try mergeService.mergeSelectedChunks(
                chunkIndices: [0],
                diffResult: diffResult,
                direction: .leftToRight
            )
            
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.changesApplied, 1)
        }
    }
    
    func testMergeEmptySelection() throws {
        // Create test files
        let leftContent = "Line 1\nLine 2"
        let rightContent = "Line 1\nLine 2 Modified"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        // Merge with empty selection
        let result = try mergeService.mergeSelectedChunks(
            chunkIndices: [],
            diffResult: diffResult,
            direction: .leftToRight
        )
        
        // Should succeed with no changes
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.changesApplied, 0)
    }
    
    // MARK: - Preview Tests
    
    func testPreviewChunkMerge() throws {
        // Create test files
        let leftContent = "Line 1\nLeft Line 2\nLine 3"
        let rightContent = "Line 1\nRight Line 2\nLine 3"
        
        let leftFile = createTestFile(named: "left.txt", content: leftContent)
        let rightFile = createTestFile(named: "right.txt", content: rightContent)
        
        // Get diff result
        let diffResult = fileComparisonService.compareFiles(leftURL: leftFile, rightURL: rightFile)
        
        guard diffResult.chunks.count > 0 else {
            XCTFail("Expected at least one chunk")
            return
        }
        
        // Get preview - should NOT modify the actual file
        let preview = try mergeService.previewChunkMerge(
            chunkIndex: 0,
            diffResult: diffResult,
            direction: .leftToRight
        )
        
        // Verify preview is not empty
        XCTAssertFalse(preview.isEmpty)
        
        // Verify original file was NOT modified
        let originalRightContent = readFile(at: rightFile)
        XCTAssertEqual(originalRightContent, rightContent)
    }
    
    // MARK: - MergeDirection Tests
    
    func testMergeDirectionDescription() {
        XCTAssertEqual(MergeDirection.leftToRight.description, "Left → Right")
        XCTAssertEqual(MergeDirection.rightToLeft.description, "Right → Left")
    }
}

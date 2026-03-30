import XCTest
@testable import SwiftCompare

final class FileComparisonServiceTests: XCTestCase {
    var service: FileComparisonService!
    
    override func setUp() {
        super.setUp()
        service = FileComparisonService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testCompareIdenticalStrings() {
        let text = "Line 1\nLine 2\nLine 3"
        let result = service.compareStrings(left: text, right: text)
        
        XCTAssertTrue(result.isIdentical)
        XCTAssertEqual(result.chunks.count, 0)
    }
    
    func testCompareStringsWithAddition() {
        let left = "Line 1\nLine 2"
        let right = "Line 1\nLine 2\nLine 3"
        let result = service.compareStrings(left: left, right: right)
        
        XCTAssertFalse(result.isIdentical)
        XCTAssertGreaterThan(result.chunks.count, 0)
    }
    
    func testCompareStringsWithRemoval() {
        let left = "Line 1\nLine 2\nLine 3"
        let right = "Line 1\nLine 3"
        let result = service.compareStrings(left: left, right: right)
        
        XCTAssertFalse(result.isIdentical)
        XCTAssertGreaterThan(result.chunks.count, 0)
    }
    
    func testCompareStringsWithModification() {
        let left = "Line 1\nLine 2\nLine 3"
        let right = "Line 1\nLine 2 Modified\nLine 3"
        let result = service.compareStrings(left: left, right: right)
        
        XCTAssertFalse(result.isIdentical)
    }
    
    func testCompareEmptyStrings() {
        let result = service.compareStrings(left: "", right: "")
        XCTAssertTrue(result.isIdentical)
    }
    
    func testCompareEmptyWithContent() {
        let result = service.compareStrings(left: "", right: "Some content")
        XCTAssertFalse(result.isIdentical)
    }
    
    func testDiffStatistics() {
        let left = "Line 1\nLine 2\nLine 3"
        let right = "Line 1\nLine 3\nLine 4"
        let result = service.compareStrings(left: left, right: right)
        
        XCTAssertFalse(result.isIdentical)
        XCTAssertGreaterThan(result.statistics.totalChanges, 0)
    }
}

final class DiffResultTests: XCTestCase {
    func testDiffStatisticsSummaryForIdentical() {
        let stats = DiffStatistics(added: 0, removed: 0, modified: 0, unchanged: 10)
        XCTAssertEqual(stats.summary, "Files are identical")
    }
    
    func testDiffStatisticsSummaryWithChanges() {
        let stats = DiffStatistics(added: 5, removed: 3, modified: 2, unchanged: 10)
        XCTAssertTrue(stats.summary.contains("+5"))
        XCTAssertTrue(stats.summary.contains("-3"))
        XCTAssertTrue(stats.summary.contains("~2"))
    }
    
    func testDiffStatisticsTotalChanges() {
        let stats = DiffStatistics(added: 5, removed: 3, modified: 2, unchanged: 10)
        XCTAssertEqual(stats.totalChanges, 10)
    }
}

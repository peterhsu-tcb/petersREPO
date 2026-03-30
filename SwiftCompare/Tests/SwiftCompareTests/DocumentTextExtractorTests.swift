import XCTest
@testable import SwiftCompare

final class DocumentTextExtractorTests: XCTestCase {
    var extractor: DocumentTextExtractor!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        extractor = DocumentTextExtractor()
        
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempDirectory)
        extractor = nil
        super.tearDown()
    }
    
    // MARK: - Extension Support Tests
    
    func testIsSupportedExtension() {
        XCTAssertTrue(DocumentTextExtractor.isSupported(extension: "pdf"))
        XCTAssertTrue(DocumentTextExtractor.isSupported(extension: "PDF"))
        XCTAssertTrue(DocumentTextExtractor.isSupported(extension: "docx"))
        XCTAssertTrue(DocumentTextExtractor.isSupported(extension: "DOCX"))
        
        XCTAssertFalse(DocumentTextExtractor.isSupported(extension: "txt"))
        XCTAssertFalse(DocumentTextExtractor.isSupported(extension: "doc"))
        XCTAssertFalse(DocumentTextExtractor.isSupported(extension: "xlsx"))
    }
    
    func testIsSupportedURL() {
        let pdfURL = URL(fileURLWithPath: "/test/document.pdf")
        let docxURL = URL(fileURLWithPath: "/test/document.docx")
        let txtURL = URL(fileURLWithPath: "/test/document.txt")
        
        XCTAssertTrue(DocumentTextExtractor.isSupported(url: pdfURL))
        XCTAssertTrue(DocumentTextExtractor.isSupported(url: docxURL))
        XCTAssertFalse(DocumentTextExtractor.isSupported(url: txtURL))
    }
    
    // MARK: - Error Handling Tests
    
    func testExtractFromNonexistentFile() {
        let nonexistentURL = tempDirectory.appendingPathComponent("nonexistent.pdf")
        
        XCTAssertThrowsError(try extractor.extractText(from: nonexistentURL)) { error in
            if let extractionError = error as? DocumentTextExtractor.ExtractionError {
                XCTAssertTrue(extractionError.localizedDescription.contains("File not found"))
            } else {
                XCTFail("Expected ExtractionError.fileNotFound")
            }
        }
    }
    
    func testExtractFromUnsupportedFormat() {
        // Create a temporary file with unsupported extension
        let txtURL = tempDirectory.appendingPathComponent("test.txt")
        try? "test content".write(to: txtURL, atomically: true, encoding: .utf8)
        
        XCTAssertThrowsError(try extractor.extractText(from: txtURL)) { error in
            if let extractionError = error as? DocumentTextExtractor.ExtractionError {
                XCTAssertTrue(extractionError.localizedDescription.contains("Unsupported"))
            } else {
                XCTFail("Expected ExtractionError.unsupportedFormat")
            }
        }
    }
    
    // MARK: - Supported Extensions Array Test
    
    func testSupportedExtensionsArray() {
        let extensions = DocumentTextExtractor.supportedExtensions
        
        XCTAssertTrue(extensions.contains("pdf"))
        XCTAssertTrue(extensions.contains("docx"))
        XCTAssertEqual(extensions.count, 2)
    }
    
    // MARK: - Error Description Tests
    
    func testExtractionErrorDescriptions() {
        let fileNotFoundError = DocumentTextExtractor.ExtractionError.fileNotFound("/path/to/file.pdf")
        XCTAssertTrue(fileNotFoundError.localizedDescription.contains("File not found"))
        XCTAssertTrue(fileNotFoundError.localizedDescription.contains("/path/to/file.pdf"))
        
        let unsupportedError = DocumentTextExtractor.ExtractionError.unsupportedFormat("xyz")
        XCTAssertTrue(unsupportedError.localizedDescription.contains("Unsupported"))
        XCTAssertTrue(unsupportedError.localizedDescription.contains("xyz"))
        
        let extractionFailedError = DocumentTextExtractor.ExtractionError.extractionFailed("Something went wrong")
        XCTAssertTrue(extractionFailedError.localizedDescription.contains("Failed to extract"))
        XCTAssertTrue(extractionFailedError.localizedDescription.contains("Something went wrong"))
    }
}

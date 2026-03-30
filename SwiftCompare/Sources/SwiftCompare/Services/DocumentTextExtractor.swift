import Foundation
import PDFKit
import AppKit

/// Service for extracting text content from document files like PDF and DOCX
class DocumentTextExtractor {
    
    /// Errors that can occur during text extraction
    enum ExtractionError: Error, LocalizedError {
        case fileNotFound(String)
        case unsupportedFormat(String)
        case extractionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .unsupportedFormat(let ext):
                return "Unsupported file format: \(ext)"
            case .extractionFailed(let message):
                return "Failed to extract text: \(message)"
            }
        }
    }
    
    /// Supported document extensions
    static let supportedExtensions = ["pdf", "docx"]
    
    /// Check if a file extension is supported for text extraction
    static func isSupported(extension ext: String) -> Bool {
        return supportedExtensions.contains(ext.lowercased())
    }
    
    /// Check if a URL points to a supported document file
    static func isSupported(url: URL) -> Bool {
        return isSupported(extension: url.pathExtension)
    }
    
    /// Extract text content from a document file
    /// - Parameter url: URL of the document file
    /// - Returns: Extracted text content
    func extractText(from url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.fileNotFound(url.path)
        }
        
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return try extractTextFromPDF(url: url)
        case "docx":
            return try extractTextFromDOCX(url: url)
        default:
            throw ExtractionError.unsupportedFormat(ext)
        }
    }
    
    // MARK: - PDF Extraction
    
    /// Extract text from a PDF file using PDFKit
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ExtractionError.extractionFailed("Could not open PDF document")
        }
        
        var fullText = ""
        let pageCount = pdfDocument.pageCount
        
        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            if let pageText = page.string {
                if !fullText.isEmpty {
                    fullText += "\n"
                }
                fullText += pageText
            }
        }
        
        return fullText
    }
    
    // MARK: - DOCX Extraction
    
    /// Extract text from a DOCX file
    /// DOCX is a ZIP archive containing XML files. The main content is in word/document.xml
    private func extractTextFromDOCX(url: URL) throws -> String {
        // Create a temporary directory to unzip the DOCX
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Use NSFileCoordinator and unzip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", url.path, "-d", tempDir.path]
            
            let pipe = Pipe()
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            // Read the document.xml file
            let documentXMLPath = tempDir.appendingPathComponent("word/document.xml")
            
            guard FileManager.default.fileExists(atPath: documentXMLPath.path) else {
                throw ExtractionError.extractionFailed("DOCX file does not contain word/document.xml")
            }
            
            let xmlData = try Data(contentsOf: documentXMLPath)
            let text = try parseWordDocumentXML(data: xmlData)
            
            return text
        } catch let error as ExtractionError {
            throw error
        } catch {
            throw ExtractionError.extractionFailed(error.localizedDescription)
        }
    }
    
    /// Parse the Word document XML and extract text content
    private func parseWordDocumentXML(data: Data) throws -> String {
        // Use XMLParser to extract text from <w:t> elements
        let parser = WordDocumentXMLParser()
        
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            if let error = xmlParser.parserError {
                throw ExtractionError.extractionFailed("XML parsing failed: \(error.localizedDescription)")
            }
            throw ExtractionError.extractionFailed("XML parsing failed")
        }
        
        return parser.extractedText
    }
}

// MARK: - Word Document XML Parser

/// XMLParser delegate for extracting text from Word document XML
private class WordDocumentXMLParser: NSObject, XMLParserDelegate {
    var extractedText = ""
    private var currentText = ""
    private var isInTextElement = false
    private var isInParagraph = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // <w:t> is the text element in Word documents
        if elementName == "w:t" {
            isInTextElement = true
            currentText = ""
        } else if elementName == "w:p" {
            // Start of a paragraph
            isInParagraph = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInTextElement {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" {
            isInTextElement = false
            extractedText += currentText
        } else if elementName == "w:p" {
            // End of paragraph - add newline
            isInParagraph = false
            if !extractedText.isEmpty && !extractedText.hasSuffix("\n") {
                extractedText += "\n"
            }
        }
    }
}

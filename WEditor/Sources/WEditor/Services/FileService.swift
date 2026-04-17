import Foundation

/// Service for file I/O operations
class FileService {
    
    /// Supported text encodings for detection
    static let supportedEncodings: [String.Encoding] = [
        .utf8, .utf16, .utf16BigEndian, .utf16LittleEndian,
        .utf32, .utf32BigEndian, .utf32LittleEndian,
        .ascii, .isoLatin1, .isoLatin2, .windowsCP1252,
        .japaneseEUC, .shiftJIS, .macOSRoman
    ]
    
    /// Read a file and return its content with detected encoding
    func readFile(at url: URL) throws -> (content: String, encoding: String.Encoding) {
        let data = try Data(contentsOf: url)
        
        // Try UTF-8 first (most common)
        if let content = String(data: data, encoding: .utf8) {
            return (content, .utf8)
        }
        
        // Try other encodings
        for encoding in FileService.supportedEncodings {
            if let content = String(data: data, encoding: encoding) {
                return (content, encoding)
            }
        }
        
        // Fallback: try lossy UTF-8
        let content = String(decoding: data, as: UTF8.self)
        return (content, .utf8)
    }
    
    /// Write content to a file with specified encoding
    func writeFile(content: String, to url: URL, encoding: String.Encoding = .utf8) throws {
        guard let data = content.data(using: encoding) else {
            throw FileServiceError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
    }
    
    /// Check if file exists
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Get file size
    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Check if file is a text file (basic heuristic)
    func isTextFile(at url: URL) -> Bool {
        let textExtensions: Set<String> = [
            "txt", "md", "markdown", "mdown", "rst",
            "swift", "py", "pyw", "pyi", "js", "mjs", "cjs", "ts", "tsx", "jsx",
            "java", "cs", "cpp", "cc", "cxx", "c", "h", "hpp", "hxx", "m", "mm",
            "rb", "rake", "go", "rs", "php",
            "html", "htm", "xhtml", "css", "scss", "less", "sass",
            "json", "jsonl", "xml", "xsl", "xslt", "svg", "plist",
            "yml", "yaml", "toml", "ini", "cfg", "conf",
            "sql", "sh", "bash", "zsh", "fish", "bat", "cmd", "ps1",
            "pl", "pm", "lua", "r", "rmd",
            "kt", "kts", "scala", "sc", "dart",
            "ex", "exs", "erl", "hs", "lhs", "elm",
            "dockerfile", "makefile", "cmake",
            "gitignore", "gitattributes", "editorconfig",
            "env", "log", "csv", "tsv"
        ]
        
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        
        if textExtensions.contains(ext) { return true }
        
        // Check special filenames
        let textFilenames: Set<String> = [
            "dockerfile", "makefile", "gnumakefile",
            "gemfile", "rakefile", "podfile",
            "license", "readme", "changelog", "contributing",
            ".gitignore", ".gitattributes", ".editorconfig",
            ".env", ".bashrc", ".zshrc", ".profile"
        ]
        
        return textFilenames.contains(name)
    }
}

/// File service errors
enum FileServiceError: Error, LocalizedError {
    case encodingFailed
    case fileNotFound
    case readFailed(String)
    case writeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode file content"
        case .fileNotFound:
            return "File not found"
        case .readFailed(let message):
            return "Failed to read file: \(message)"
        case .writeFailed(let message):
            return "Failed to write file: \(message)"
        }
    }
}

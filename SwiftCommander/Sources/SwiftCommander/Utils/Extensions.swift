import Foundation
import SwiftUI

// MARK: - URL Extensions

extension URL {
    /// Check if URL is a directory
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    /// Check if URL is hidden
    var isHidden: Bool {
        (try? resourceValues(forKeys: [.isHiddenKey]))?.isHidden ?? false
    }
    
    /// Get file size
    var fileSize: Int64 {
        (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map { Int64($0) } ?? 0
    }
    
    /// Get modification date
    var modificationDate: Date? {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
    
    /// Check if file is readable
    var isReadable: Bool {
        FileManager.default.isReadableFile(atPath: path)
    }
    
    /// Check if file is writable
    var isWritable: Bool {
        FileManager.default.isWritableFile(atPath: path)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date as relative string (e.g., "2 hours ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format date for file listing
    var fileListingString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - Int64 Extensions

extension Int64 {
    /// Format bytes as human-readable size
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string is a valid filename
    var isValidFilename: Bool {
        !isEmpty && !contains("/") && !contains(":") && self != "." && self != ".."
    }
    
    /// Sanitize string for use as filename
    var sanitizedFilename: String {
        var result = self
        let invalidChars = CharacterSet(charactersIn: "/:\\")
        result = result.components(separatedBy: invalidChars).joined(separator: "_")
        return result.isEmpty ? "untitled" : result
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply a conditional modifier with else clause
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// File type colors
    static let fileDirectory = Color.blue
    static let fileImage = Color.purple
    static let fileVideo = Color.pink
    static let fileAudio = Color.orange
    static let fileArchive = Color.brown
    static let fileCode = Color.green
    static let fileText = Color.gray
    static let fileExecutable = Color.red
    static let fileOther = Color.secondary
    
    /// Get color for file type
    static func forFileType(_ type: FileType) -> Color {
        switch type {
        case .text: return .fileText
        case .image: return .fileImage
        case .video: return .fileVideo
        case .audio: return .fileAudio
        case .archive: return .fileArchive
        case .pdf: return .red
        case .code: return .fileCode
        case .executable: return .fileExecutable
        case .other: return .fileOther
        }
    }
}

// MARK: - Keyboard Shortcuts

struct KeyboardShortcuts {
    static let copy = KeyboardShortcut("c", modifiers: .command)
    static let paste = KeyboardShortcut("v", modifiers: .command)
    static let cut = KeyboardShortcut("x", modifiers: .command)
    static let selectAll = KeyboardShortcut("a", modifiers: .command)
    static let delete = KeyboardShortcut(.delete, modifiers: .command)
    static let newFolder = KeyboardShortcut("n", modifiers: .command)
    static let refresh = KeyboardShortcut("r", modifiers: .command)
    static let find = KeyboardShortcut("f", modifiers: .command)
    static let goTo = KeyboardShortcut("g", modifiers: .command)
    static let toggleHidden = KeyboardShortcut("h", modifiers: [.command, .shift])
    static let focusLeft = KeyboardShortcut("1", modifiers: .command)
    static let focusRight = KeyboardShortcut("2", modifiers: .command)
    static let goUp = KeyboardShortcut(.upArrow, modifiers: .command)
    static let goBack = KeyboardShortcut(.leftArrow, modifiers: .command)
    static let goForward = KeyboardShortcut(.rightArrow, modifiers: .command)
    static let tab = KeyboardShortcut(.tab, modifiers: [])
    static let properties = KeyboardShortcut("i", modifiers: .command)
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Calculate total size of directory contents
    func directorySize(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            size += Int64(fileSize)
        }
        
        return size
    }
    
    /// Count files and directories in a path
    func directoryContents(at url: URL) throws -> (files: Int, directories: Int) {
        var files = 0
        var directories = 0
        
        let contents = try contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        
        for item in contents {
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                directories += 1
            } else {
                files += 1
            }
        }
        
        return (files, directories)
    }
}

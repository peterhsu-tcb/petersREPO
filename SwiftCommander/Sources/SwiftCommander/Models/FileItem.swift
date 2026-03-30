import Foundation

/// Represents a file or directory in the file system
struct FileItem: Identifiable, Hashable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let creationDate: Date
    let isHidden: Bool
    let isSymbolicLink: Bool
    let permissions: FilePermissions
    let fileType: FileType
    
    /// File type extension for display
    var fileExtension: String {
        if isDirectory {
            return ""
        }
        return url.pathExtension.lowercased()
    }
    
    /// Human-readable file size
    var formattedSize: String {
        if isDirectory {
            return "<DIR>"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// Human-readable modification date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    /// Icon name for the file type
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        switch fileType {
        case .text:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "film.fill"
        case .audio:
            return "music.note"
        case .archive:
            return "doc.zipper"
        case .pdf:
            return "doc.fill"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .executable:
            return "app.fill"
        case .other:
            return "doc.fill"
        }
    }
    
    init(url: URL, isDirectory: Bool, size: Int64, modificationDate: Date, creationDate: Date, isHidden: Bool, isSymbolicLink: Bool, permissions: FilePermissions) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.isHidden = isHidden
        self.isSymbolicLink = isSymbolicLink
        self.permissions = permissions
        self.fileType = FileType.from(extension: url.pathExtension)
    }
    
    /// Creates a FileItem from a URL by reading file attributes
    static func from(url: URL) -> FileItem? {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let resourceValues = try url.resourceValues(forKeys: [.isHiddenKey, .isSymbolicLinkKey])
            
            let isDirectory = (attributes[.type] as? FileAttributeType) == .typeDirectory
            let size = (attributes[.size] as? Int64) ?? 0
            let modificationDate = (attributes[.modificationDate] as? Date) ?? Date()
            let creationDate = (attributes[.creationDate] as? Date) ?? Date()
            let isHidden = resourceValues.isHidden ?? false
            let isSymbolicLink = resourceValues.isSymbolicLink ?? false
            let posixPermissions = (attributes[.posixPermissions] as? Int) ?? 0
            
            return FileItem(
                url: url,
                isDirectory: isDirectory,
                size: size,
                modificationDate: modificationDate,
                creationDate: creationDate,
                isHidden: isHidden,
                isSymbolicLink: isSymbolicLink,
                permissions: FilePermissions(posix: posixPermissions)
            )
        } catch {
            return nil
        }
    }
    
    /// Parent directory item (for navigating up)
    static func parentDirectory(for url: URL) -> FileItem {
        let parentURL = url.deletingLastPathComponent()
        return FileItem(
            url: parentURL,
            isDirectory: true,
            size: 0,
            modificationDate: Date(),
            creationDate: Date(),
            isHidden: false,
            isSymbolicLink: false,
            permissions: FilePermissions(posix: 0o755)
        )
    }
}

/// File type classification
enum FileType: String, CaseIterable {
    case text
    case image
    case video
    case audio
    case archive
    case pdf
    case code
    case executable
    case other
    
    static func from(extension ext: String) -> FileType {
        let lowered = ext.lowercased()
        
        let textExtensions = ["txt", "md", "rtf", "log", "csv", "json", "xml", "yaml", "yml"]
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "ico", "svg"]
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "wma", "m4a", "aiff"]
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso"]
        let codeExtensions = ["swift", "py", "js", "ts", "java", "c", "cpp", "h", "hpp", "cs", "go", "rs", "rb", "php", "html", "css", "scss", "less", "sql", "sh", "bash", "zsh"]
        let executableExtensions = ["app", "exe", "dll", "so", "dylib"]
        
        if lowered == "pdf" {
            return .pdf
        } else if textExtensions.contains(lowered) {
            return .text
        } else if imageExtensions.contains(lowered) {
            return .image
        } else if videoExtensions.contains(lowered) {
            return .video
        } else if audioExtensions.contains(lowered) {
            return .audio
        } else if archiveExtensions.contains(lowered) {
            return .archive
        } else if codeExtensions.contains(lowered) {
            return .code
        } else if executableExtensions.contains(lowered) {
            return .executable
        }
        
        return .other
    }
}

/// File permissions representation
struct FilePermissions: Hashable, Equatable {
    let owner: PermissionSet
    let group: PermissionSet
    let others: PermissionSet
    
    init(posix: Int) {
        self.owner = PermissionSet(
            read: (posix & 0o400) != 0,
            write: (posix & 0o200) != 0,
            execute: (posix & 0o100) != 0
        )
        self.group = PermissionSet(
            read: (posix & 0o040) != 0,
            write: (posix & 0o020) != 0,
            execute: (posix & 0o010) != 0
        )
        self.others = PermissionSet(
            read: (posix & 0o004) != 0,
            write: (posix & 0o002) != 0,
            execute: (posix & 0o001) != 0
        )
    }
    
    /// String representation like "rwxr-xr-x"
    var displayString: String {
        return owner.displayString + group.displayString + others.displayString
    }
}

/// Permission set for owner/group/others
struct PermissionSet: Hashable, Equatable {
    let read: Bool
    let write: Bool
    let execute: Bool
    
    var displayString: String {
        var result = ""
        result += read ? "r" : "-"
        result += write ? "w" : "-"
        result += execute ? "x" : "-"
        return result
    }
}

/// Sort order for file listing
enum SortOrder: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case sizeAscending = "Size (Small first)"
    case sizeDescending = "Size (Large first)"
    case dateAscending = "Date (Oldest first)"
    case dateDescending = "Date (Newest first)"
    case typeAscending = "Type (A-Z)"
    case typeDescending = "Type (Z-A)"
    
    /// Whether this sort order is ascending
    var isAscending: Bool {
        switch self {
        case .nameAscending, .sizeAscending, .dateAscending, .typeAscending:
            return true
        case .nameDescending, .sizeDescending, .dateDescending, .typeDescending:
            return false
        }
    }
    
    /// Comparator function for sorting FileItems
    var comparator: (FileItem, FileItem) -> Bool {
        switch self {
        case .nameAscending:
            return { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .sizeAscending:
            return { $0.size < $1.size }
        case .sizeDescending:
            return { $0.size > $1.size }
        case .dateAscending:
            return { $0.modificationDate < $1.modificationDate }
        case .dateDescending:
            return { $0.modificationDate > $1.modificationDate }
        case .typeAscending:
            return { $0.fileExtension.localizedCaseInsensitiveCompare($1.fileExtension) == .orderedAscending }
        case .typeDescending:
            return { $0.fileExtension.localizedCaseInsensitiveCompare($1.fileExtension) == .orderedDescending }
        }
    }
}

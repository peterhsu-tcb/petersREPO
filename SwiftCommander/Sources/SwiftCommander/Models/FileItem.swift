import Foundation

/// Represents a file or directory in the file system
struct FileItem: Identifiable, Hashable, Comparable {
    let id: UUID
    let url: URL
    let name: String
    let isDirectory: Bool
    let isHidden: Bool
    let isSymlink: Bool
    let size: Int64
    let modificationDate: Date?
    let creationDate: Date?
    let permissions: String
    let owner: String
    
    /// Parent directory marker
    static let parentDirectory = FileItem(
        id: UUID(),
        url: URL(fileURLWithPath: ".."),
        name: "..",
        isDirectory: true,
        isHidden: false,
        isSymlink: false,
        size: 0,
        modificationDate: nil,
        creationDate: nil,
        permissions: "",
        owner: ""
    )
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        
        let resourceValues = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey
        ])
        
        self.isDirectory = resourceValues?.isDirectory ?? false
        self.isHidden = resourceValues?.isHidden ?? false
        self.isSymlink = resourceValues?.isSymbolicLink ?? false
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.modificationDate = resourceValues?.contentModificationDate
        self.creationDate = resourceValues?.creationDate
        
        // Get POSIX permissions and owner
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let posixPermissions = attributes?[.posixPermissions] as? Int {
            self.permissions = FileItem.permissionsString(from: posixPermissions)
        } else {
            self.permissions = ""
        }
        self.owner = attributes?[.ownerAccountName] as? String ?? ""
    }
    
    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        isHidden: Bool,
        isSymlink: Bool,
        size: Int64,
        modificationDate: Date?,
        creationDate: Date?,
        permissions: String,
        owner: String
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.permissions = permissions
        self.owner = owner
    }
    
    /// Returns a human-readable file size string
    var formattedSize: String {
        if isDirectory {
            return "<DIR>"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// Returns a formatted modification date string
    var formattedModificationDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// File extension
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    /// System icon for the file type
    var iconName: String {
        if name == ".." {
            return "arrow.up.doc"
        }
        if isDirectory {
            return isSymlink ? "folder.badge.plus" : "folder.fill"
        }
        
        switch fileExtension {
        case "swift", "py", "js", "ts", "c", "cpp", "h", "java", "go", "rs":
            return "doc.text.fill"
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "svg", "webp":
            return "photo.fill"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "mp4", "mov", "avi", "mkv", "webm":
            return "film.fill"
        case "pdf":
            return "doc.richtext.fill"
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"
        case "app":
            return "app.fill"
        case "dmg", "iso":
            return "opticaldisc.fill"
        case "txt", "md", "rtf":
            return "doc.text"
        case "html", "css", "xml", "json":
            return "globe"
        default:
            return isSymlink ? "link" : "doc"
        }
    }
    
    /// Convert POSIX permissions to string format (e.g., "rwxr-xr-x")
    static func permissionsString(from posix: Int) -> String {
        let permissions = [
            (posix & 0o400 != 0 ? "r" : "-"),
            (posix & 0o200 != 0 ? "w" : "-"),
            (posix & 0o100 != 0 ? "x" : "-"),
            (posix & 0o040 != 0 ? "r" : "-"),
            (posix & 0o020 != 0 ? "w" : "-"),
            (posix & 0o010 != 0 ? "x" : "-"),
            (posix & 0o004 != 0 ? "r" : "-"),
            (posix & 0o002 != 0 ? "w" : "-"),
            (posix & 0o001 != 0 ? "x" : "-")
        ]
        return permissions.joined()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Sort directories first, then by name
    static func < (lhs: FileItem, rhs: FileItem) -> Bool {
        if lhs.name == ".." { return true }
        if rhs.name == ".." { return false }
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

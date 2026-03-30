import Foundation
import AppKit

/// Service for file navigation and opening
class NavigationService {
    
    private let fileManager = FileManager.default
    private let workspace = NSWorkspace.shared
    
    // MARK: - Directory Navigation
    
    /// Navigate to a URL and return the directory contents
    func navigateTo(url: URL) throws -> [FileItem] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw NavigationError.pathNotFound(url.path)
        }
        
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        guard isDirectory.boolValue else {
            throw NavigationError.notADirectory(url.path)
        }
        
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw NavigationError.accessDenied(url.path)
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isHiddenKey,
                .isSymbolicLinkKey
            ],
            options: []
        )
        
        return contents.compactMap { FileItem.from(url: $0) }
    }
    
    /// Get path components for breadcrumb navigation
    func pathComponents(for url: URL) -> [(name: String, url: URL)] {
        var components: [(name: String, url: URL)] = []
        var currentURL = url
        
        while currentURL.path != "/" {
            components.insert((currentURL.lastPathComponent, currentURL), at: 0)
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        // Add root
        components.insert(("/", URL(fileURLWithPath: "/")), at: 0)
        
        return components
    }
    
    // MARK: - File Operations
    
    /// Open a file with the default application
    func openFile(at url: URL) {
        workspace.open(url)
    }
    
    /// Open a file with a specific application
    func openFile(at url: URL, withApplication appURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        workspace.open([url], withApplicationAt: appURL, configuration: configuration)
    }
    
    /// Open file in default text editor
    func openInTextEditor(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        if let textEditURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
            workspace.open([url], withApplicationAt: textEditURL, configuration: configuration)
        } else {
            workspace.open(url)
        }
    }
    
    /// Reveal file in Finder
    func revealInFinder(at url: URL) {
        workspace.activateFileViewerSelecting([url])
    }
    
    /// Open Terminal at directory
    func openTerminal(at url: URL) {
        let script = """
            tell application "Terminal"
                do script "cd '\(url.path.replacingOccurrences(of: "'", with: "\\'"))'"
                activate
            end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    /// Quick Look preview
    func quickLook(at url: URL) {
        // Quick Look is typically handled by the view layer with QLPreviewPanel
        // This is a placeholder for the URL to preview
    }
    
    // MARK: - Special Directories
    
    /// Get home directory
    var homeDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
    }
    
    /// Get Desktop directory
    var desktopDirectory: URL? {
        fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
    
    /// Get Documents directory
    var documentsDirectory: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// Get Downloads directory
    var downloadsDirectory: URL? {
        fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    /// Get Applications directory
    var applicationsDirectory: URL {
        URL(fileURLWithPath: "/Applications")
    }
    
    /// Get root directory
    var rootDirectory: URL {
        URL(fileURLWithPath: "/")
    }
    
    /// Get Trash directory
    var trashDirectory: URL? {
        fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
    }
    
    /// Get mounted volumes
    func mountedVolumes() -> [URL] {
        return fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }
    
    // MARK: - File Type Handling
    
    /// Get applications that can open a file
    func applicationsForFile(at url: URL) -> [URL] {
        return workspace.urlsForApplications(toOpen: url)
    }
    
    /// Get default application for file
    func defaultApplication(for url: URL) -> URL? {
        return workspace.urlForApplication(toOpen: url)
    }
    
    /// Get file type description
    func fileTypeDescription(for url: URL) -> String? {
        guard let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
            return nil
        }
        return workspace.localizedDescription(forType: uti)
    }
    
    /// Get file icon
    func fileIcon(for url: URL) -> NSImage {
        return workspace.icon(forFile: url.path)
    }
}

/// Navigation errors
enum NavigationError: Error, LocalizedError {
    case pathNotFound(String)
    case notADirectory(String)
    case accessDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .accessDenied(let path):
            return "Access denied: \(path)"
        }
    }
}

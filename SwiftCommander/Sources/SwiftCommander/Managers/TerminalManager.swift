import Foundation
import AppKit

/// Manages terminal integration
class TerminalManager {
    static let shared = TerminalManager()
    
    private init() {}
    
    /// Terminal application types
    enum TerminalApp: String, CaseIterable {
        case terminal = "Terminal"
        case iterm = "iTerm"
        
        var bundleIdentifier: String {
            switch self {
            case .terminal:
                return "com.apple.Terminal"
            case .iterm:
                return "com.googlecode.iterm2"
            }
        }
    }
    
    /// Open terminal at a specific directory
    func openTerminal(at directory: URL, app: TerminalApp = .terminal) {
        switch app {
        case .terminal:
            openMacOSTerminal(at: directory)
        case .iterm:
            openITerm(at: directory)
        }
    }
    
    /// Open macOS Terminal.app at directory
    private func openMacOSTerminal(at directory: URL) {
        let script = """
            tell application "Terminal"
                activate
                do script "cd '\(directory.path.replacingOccurrences(of: "'", with: "'\\''"))'"
            end tell
            """
        
        runAppleScript(script)
    }
    
    /// Open iTerm at directory
    private func openITerm(at directory: URL) {
        let script = """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "cd '\(directory.path.replacingOccurrences(of: "'", with: "'\\''"))'"
                end tell
            end tell
            """
        
        runAppleScript(script)
    }
    
    /// Run an AppleScript
    private func runAppleScript(_ script: String) {
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
    
    /// Open a file with its default application
    func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    /// Open a file with a specific application
    func openFile(_ url: URL, withApp appURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }
    
    /// Reveal file in Finder
    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    /// Get file info (equivalent to Cmd+I in Finder)
    func showFileInfo(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
        
        // Use AppleScript to show Get Info
        let script = """
            tell application "Finder"
                activate
                open information window of (POSIX file "\(url.path)" as alias)
            end tell
            """
        
        runAppleScript(script)
    }
    
    /// Copy file path to clipboard
    func copyPathToClipboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }
    
    /// Copy file URL to clipboard
    func copyURLToClipboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
    }
    
    /// Run a shell command in the current directory
    func runCommand(_ command: String, in directory: URL) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

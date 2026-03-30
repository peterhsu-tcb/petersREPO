import SwiftUI

/// Main application entry point
@main
struct SwiftCompareApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Comparison") {
                    appState.resetComparison()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Divider()
                
                Button("Compare Files...") {
                    appState.comparisonMode = .files
                    appState.showFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Compare Folders...") {
                    appState.comparisonMode = .folders
                    appState.showFolderPicker = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            
            CommandMenu("Compare") {
                Button("Refresh") {
                    appState.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Button("Previous Difference") {
                    appState.goToPreviousDifference()
                }
                .keyboardShortcut("[", modifiers: .command)
                
                Button("Next Difference") {
                    appState.goToNextDifference()
                }
                .keyboardShortcut("]", modifiers: .command)
                
                Divider()
                
                Toggle("Show Only Differences", isOn: $appState.showOnlyDifferences)
                    .keyboardShortcut("d", modifiers: .command)
            }
            
            CommandMenu("Merge") {
                Button("Copy Left to Right") {
                    appState.copyLeftToRight()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(appState.selectedComparisonItem == nil)
                
                Button("Copy Right to Left") {
                    appState.copyRightToLeft()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(appState.selectedComparisonItem == nil)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

/// Comparison mode - files or folders
enum ComparisonMode {
    case files
    case folders
}

/// Application state shared across views
class AppState: ObservableObject {
    @Published var comparisonMode: ComparisonMode = .files
    @Published var leftPath: URL?
    @Published var rightPath: URL?
    @Published var diffResult: DiffResult?
    @Published var folderComparisonResult: FolderComparisonResult?
    @Published var isComparing = false
    @Published var showOnlyDifferences = false
    @Published var showFilePicker = false
    @Published var showFolderPicker = false
    @Published var selectedComparisonItem: ComparisonItem?
    @Published var currentDifferenceIndex = 0
    @Published var errorMessage: String?
    
    private let fileComparisonService = FileComparisonService()
    private let folderComparisonService = FolderComparisonService()
    
    func resetComparison() {
        leftPath = nil
        rightPath = nil
        diffResult = nil
        folderComparisonResult = nil
        selectedComparisonItem = nil
        currentDifferenceIndex = 0
        errorMessage = nil
    }
    
    func compare() {
        guard let left = leftPath, let right = rightPath else {
            errorMessage = "Please select both left and right paths"
            return
        }
        
        isComparing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            switch self.comparisonMode {
            case .files:
                let result = self.fileComparisonService.compareFiles(leftURL: left, rightURL: right)
                DispatchQueue.main.async {
                    self.diffResult = result
                    self.isComparing = false
                }
                
            case .folders:
                let result = self.folderComparisonService.compareFolders(leftURL: left, rightURL: right)
                DispatchQueue.main.async {
                    self.folderComparisonResult = result
                    self.isComparing = false
                }
            }
        }
    }
    
    func refresh() {
        compare()
    }
    
    func goToPreviousDifference() {
        if currentDifferenceIndex > 0 {
            currentDifferenceIndex -= 1
        }
    }
    
    func goToNextDifference() {
        if let result = diffResult, currentDifferenceIndex < result.chunks.count - 1 {
            currentDifferenceIndex += 1
        }
    }
    
    func copyLeftToRight() {
        guard let item = selectedComparisonItem,
              let sourceURL = item.leftItem?.url,
              let destinationURL = rightPath?.appendingPathComponent(item.name) else {
            return
        }
        
        do {
            try folderComparisonService.synchronize(from: sourceURL, to: destinationURL, overwrite: true)
            refresh()
        } catch {
            errorMessage = "Failed to copy: \(error.localizedDescription)"
        }
    }
    
    func copyRightToLeft() {
        guard let item = selectedComparisonItem,
              let sourceURL = item.rightItem?.url,
              let destinationURL = leftPath?.appendingPathComponent(item.name) else {
            return
        }
        
        do {
            try folderComparisonService.synchronize(from: sourceURL, to: destinationURL, overwrite: true)
            refresh()
        } catch {
            errorMessage = "Failed to copy: \(error.localizedDescription)"
        }
    }
}

import SwiftUI

/// Main application entry point
@main
struct SwiftCompareApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        DispatchQueue.main.async {
            NSApp?.setActivationPolicy(.regular)
        }
    }
    
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
                
                Divider()
                
                Button("Merge All Left to Right") {
                    appState.mergeAllLeftToRight()
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(appState.diffResult == nil || appState.diffResult?.isIdentical == true)
                
                Button("Merge All Right to Left") {
                    appState.mergeAllRightToLeft()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(appState.diffResult == nil || appState.diffResult?.isIdentical == true)
                
                Divider()
                
                Button("Merge Current Chunk Left → Right") {
                    appState.mergeChunkLeftToRight(chunkIndex: appState.currentDifferenceIndex)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(appState.diffResult == nil || appState.diffResult?.chunks.isEmpty == true)
                
                Button("Merge Current Chunk Right → Left") {
                    appState.mergeChunkRightToLeft(chunkIndex: appState.currentDifferenceIndex)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(appState.diffResult == nil || appState.diffResult?.chunks.isEmpty == true)
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
    private let mergeService = MergeService()
    
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
    
    // MARK: - File Content Merge Operations
    
    /// Merge a specific diff chunk from left to right
    func mergeChunkLeftToRight(chunkIndex: Int) {
        guard let result = diffResult else {
            errorMessage = "No diff result available"
            return
        }
        
        do {
            let mergeResult = try mergeService.mergeChunkAtIndex(
                chunkIndex: chunkIndex,
                diffResult: result,
                direction: .leftToRight
            )
            if mergeResult.success {
                refresh()
            } else {
                errorMessage = mergeResult.message
            }
        } catch {
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }
    }
    
    /// Merge a specific diff chunk from right to left
    func mergeChunkRightToLeft(chunkIndex: Int) {
        guard let result = diffResult else {
            errorMessage = "No diff result available"
            return
        }
        
        do {
            let mergeResult = try mergeService.mergeChunkAtIndex(
                chunkIndex: chunkIndex,
                diffResult: result,
                direction: .rightToLeft
            )
            if mergeResult.success {
                refresh()
            } else {
                errorMessage = mergeResult.message
            }
        } catch {
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }
    }
    
    /// Merge all differences from left to right
    func mergeAllLeftToRight() {
        guard let result = diffResult else {
            errorMessage = "No diff result available"
            return
        }
        
        do {
            let mergeResult = try mergeService.mergeAllLeftToRight(diffResult: result)
            if mergeResult.success {
                refresh()
            } else {
                errorMessage = mergeResult.message
            }
        } catch {
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }
    }
    
    /// Merge all differences from right to left
    func mergeAllRightToLeft() {
        guard let result = diffResult else {
            errorMessage = "No diff result available"
            return
        }
        
        do {
            let mergeResult = try mergeService.mergeAllRightToLeft(diffResult: result)
            if mergeResult.success {
                refresh()
            } else {
                errorMessage = mergeResult.message
            }
        } catch {
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }
    }
    
    /// Merge selected chunks in a specific direction
    func mergeSelectedChunks(indices: [Int], direction: MergeDirection) {
        guard let result = diffResult else {
            errorMessage = "No diff result available"
            return
        }
        
        do {
            let mergeResult = try mergeService.mergeSelectedChunks(
                chunkIndices: indices,
                diffResult: result,
                direction: direction
            )
            if mergeResult.success {
                refresh()
            } else {
                errorMessage = mergeResult.message
            }
        } catch {
            errorMessage = "Merge failed: \(error.localizedDescription)"
        }
    }
}

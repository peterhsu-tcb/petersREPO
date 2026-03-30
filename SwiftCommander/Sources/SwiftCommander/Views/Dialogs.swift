import SwiftUI

// MARK: - New Folder Dialog

struct NewFolderDialog: View {
    @EnvironmentObject var appState: AppState
    @State private var folderName = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("New Folder")
                .font(.headline)
            
            TextField("Folder name", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { createFolder() }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Create") { createFolder() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(folderName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
    
    private func createFolder() {
        guard let pane = appState.activePane else { return }
        
        do {
            _ = try FileManagerService.shared.createFolder(at: pane.currentPath, name: folderName)
            appState.refreshActivePane()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - New File Dialog

struct NewFileDialog: View {
    @EnvironmentObject var appState: AppState
    @State private var fileName = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("New File")
                .font(.headline)
            
            TextField("File name", text: $fileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { createFile() }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Create") { createFile() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(fileName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
    
    private func createFile() {
        guard let pane = appState.activePane else { return }
        
        do {
            _ = try FileManagerService.shared.createFile(at: pane.currentPath, name: fileName)
            appState.refreshActivePane()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Rename Dialog

struct RenameDialog: View {
    @EnvironmentObject var appState: AppState
    @State private var newName = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rename")
                .font(.headline)
            
            if let item = appState.activePane?.selectedItem {
                Text("Current name: \(item.name)")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            TextField("New name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { rename() }
                .onAppear {
                    newName = appState.activePane?.selectedItem?.name ?? ""
                }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Rename") { rename() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
    
    private func rename() {
        guard let item = appState.activePane?.selectedItem else { return }
        
        do {
            _ = try FileManagerService.shared.rename(at: item.url, to: newName)
            appState.refreshActivePane()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Search Dialog

struct SearchDialog: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var searchManager = SearchManager.shared
    @State private var searchQuery = ""
    @State private var searchType: SearchManager.SearchType = .filename
    @State private var searchRecursive = true
    @State private var includeHidden = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Search")
                .font(.headline)
            
            // Search input
            TextField("Search query", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
            
            // Search options
            HStack {
                Picker("Type:", selection: $searchType) {
                    Text("Filename").tag(SearchManager.SearchType.filename)
                    Text("Content").tag(SearchManager.SearchType.content)
                    Text("Regex").tag(SearchManager.SearchType.regex)
                    Text("Spotlight").tag(SearchManager.SearchType.spotlight)
                }
                .frame(width: 200)
                
                Toggle("Recursive", isOn: $searchRecursive)
                Toggle("Hidden", isOn: $includeHidden)
            }
            
            // Search button
            HStack {
                if searchManager.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(searchManager.searchProgress)
                        .foregroundColor(.secondary)
                    
                    Button("Cancel") {
                        searchManager.cancelSearch()
                    }
                } else {
                    Button("Search") {
                        performSearch()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(searchQuery.isEmpty)
                }
            }
            
            // Results
            if !searchManager.searchResults.isEmpty {
                Divider()
                
                Text("Results: \(searchManager.searchResults.count)")
                    .font(.subheadline)
                
                List(searchManager.searchResults) { item in
                    HStack {
                        Image(systemName: item.iconName)
                            .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                        
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onTapGesture(count: 2) {
                        // Navigate to file location
                        appState.activePane?.navigateTo(item.url.deletingLastPathComponent())
                        appState.refreshActivePane()
                        dismiss()
                    }
                }
                .frame(height: 300)
            }
            
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
    
    private func performSearch() {
        guard let pane = appState.activePane else { return }
        
        Task {
            _ = await searchManager.search(
                query: searchQuery,
                in: pane.currentPath,
                type: searchType,
                recursive: searchRecursive,
                includeHidden: includeHidden
            )
        }
    }
}

// MARK: - Go To Path Dialog

struct GoToPathDialog: View {
    @EnvironmentObject var appState: AppState
    @State private var path = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Path")
                .font(.headline)
            
            TextField("Enter path", text: $path)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
                .onSubmit { goToPath() }
                .onAppear {
                    path = appState.activePane?.currentPath.path ?? ""
                }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Quick access buttons
            HStack {
                Button("Home") { path = FileManager.default.homeDirectoryForCurrentUser.path }
                Button("Root") { path = "/" }
                Button("Applications") { path = "/Applications" }
                Button("Documents") { 
                    path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path
                }
            }
            .buttonStyle(.bordered)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Go") { goToPath() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(path.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
    
    private func goToPath() {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        if FileManager.default.fileExists(atPath: url.path) {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                appState.activePane?.navigateTo(url)
            } else {
                appState.activePane?.navigateTo(url.deletingLastPathComponent())
            }
            appState.refreshActivePane()
            dismiss()
        } else {
            errorMessage = "Path does not exist"
        }
    }
}

// MARK: - Create Archive Dialog

struct CreateArchiveDialog: View {
    @EnvironmentObject var appState: AppState
    @State private var archiveName = ""
    @State private var archiveType: ArchiveManager.ArchiveType = .zip
    @State private var isCreating = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create Archive")
                .font(.headline)
            
            // Selected files info
            if let pane = appState.activePane {
                let count = pane.selectedItems.count
                Text("\(count) item(s) selected")
                    .foregroundColor(.secondary)
            }
            
            // Archive name
            TextField("Archive name", text: $archiveName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onAppear {
                    if let item = appState.activePane?.selectedItem {
                        archiveName = item.name
                    }
                }
            
            // Archive type
            Picker("Format:", selection: $archiveType) {
                ForEach(ArchiveManager.ArchiveType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .frame(width: 200)
            
            // Final filename preview
            Text("Output: \(archiveName).\(archiveType.fileExtension)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("Create") { createArchive() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(archiveName.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    private func createArchive() {
        guard let pane = appState.activePane else { return }
        
        let sources = pane.selectedFileItems.map { $0.url }
        let destination = pane.currentPath.appendingPathComponent("\(archiveName).\(archiveType.fileExtension)")
        
        isCreating = true
        
        Task {
            do {
                try await ArchiveManager.shared.createArchive(type: archiveType, from: sources, to: destination)
                await MainActor.run {
                    appState.refreshActivePane()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Copy/Move Progress Dialog

struct FileOperationProgressView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var fileManager = FileManagerService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            if let progress = fileManager.currentProgress {
                Text("Copying files...")
                    .font(.headline)
                
                Text(progress.currentFile)
                    .lineLimit(1)
                
                ProgressView(value: progress.filePercentComplete, total: 100)
                
                Text("\(progress.currentIndex) of \(progress.totalFiles)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}

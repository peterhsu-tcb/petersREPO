import SwiftUI

/// Main content view with mode selection and comparison panels
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("selectedTheme") private var selectedTheme = "system"
    
    /// Computed color scheme based on user's theme preference
    private var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // system default
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area
            ToolbarView()
            
            Divider()
            
            // Main content area
            if appState.isComparing {
                LoadingView()
            } else if appState.diffResult != nil || appState.folderComparisonResult != nil {
                ComparisonView()
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.errorMessage = nil
            }
        } message: {
            if let error = appState.errorMessage {
                Text(error)
            }
        }
        .fileImporter(
            isPresented: $appState.showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .fileImporter(
            isPresented: $appState.showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            handleFolderSelection(result)
        }
        .preferredColorScheme(preferredColorScheme)
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if urls.count >= 2 {
                appState.leftPath = urls[0]
                appState.rightPath = urls[1]
                appState.compare()
            } else if urls.count == 1 {
                if appState.leftPath == nil {
                    appState.leftPath = urls[0]
                } else {
                    appState.rightPath = urls[0]
                    appState.compare()
                }
            }
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if urls.count >= 2 {
                appState.leftPath = urls[0]
                appState.rightPath = urls[1]
                appState.compare()
            } else if urls.count == 1 {
                if appState.leftPath == nil {
                    appState.leftPath = urls[0]
                } else {
                    appState.rightPath = urls[0]
                    appState.compare()
                }
            }
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
        }
    }
}

/// Toolbar with comparison controls
struct ToolbarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            // Mode selector
            Picker("Mode", selection: $appState.comparisonMode) {
                Label("Files", systemImage: "doc.text").tag(ComparisonMode.files)
                Label("Folders", systemImage: "folder").tag(ComparisonMode.folders)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Divider()
                .frame(height: 24)
            
            // Left path selector
            PathSelector(
                label: "Left",
                path: $appState.leftPath,
                isFolder: appState.comparisonMode == .folders
            )
            
            // Swap button
            Button(action: swapPaths) {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Swap left and right")
            
            // Right path selector
            PathSelector(
                label: "Right",
                path: $appState.rightPath,
                isFolder: appState.comparisonMode == .folders
            )
            
            Divider()
                .frame(height: 24)
            
            // Compare button
            Button(action: appState.compare) {
                Label("Compare", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.leftPath == nil || appState.rightPath == nil)
            
            Spacer()
            
            // Navigation buttons
            if appState.diffResult != nil {
                HStack(spacing: 8) {
                    Button(action: appState.goToPreviousDifference) {
                        Image(systemName: "chevron.up")
                    }
                    .help("Previous difference")
                    
                    Button(action: appState.goToNextDifference) {
                        Image(systemName: "chevron.down")
                    }
                    .help("Next difference")
                }
            }
            
            // Filter toggle
            Toggle(isOn: $appState.showOnlyDifferences) {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .toggleStyle(.button)
            .help("Show only differences")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func swapPaths() {
        let temp = appState.leftPath
        appState.leftPath = appState.rightPath
        appState.rightPath = temp
        
        if appState.leftPath != nil && appState.rightPath != nil {
            appState.compare()
        }
    }
}

/// Path selector component
struct PathSelector: View {
    let label: String
    @Binding var path: URL?
    let isFolder: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            
            TextField("Select \(isFolder ? "folder" : "file")...", text: .constant(path?.path ?? ""))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200)
                .disabled(true)
            
            Button(action: selectPath) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
        }
    }
    
    private func selectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !isFolder
        panel.canChooseDirectories = isFolder
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            path = panel.url
        }
    }
}

/// Loading view during comparison
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Comparing...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Welcome view when no comparison is active
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("SwiftCompare")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("A powerful file and folder comparison tool")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: { 
                    appState.comparisonMode = .files
                    appState.showFilePicker = true
                }) {
                    Label("Compare Files", systemImage: "doc.text")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    appState.comparisonMode = .folders
                    appState.showFolderPicker = true
                }) {
                    Label("Compare Folders", systemImage: "folder")
                        .frame(width: 200)
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
                .frame(width: 200)
            
            Text("Or drag and drop files/folders here")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let path = String(data: data, encoding: .utf8),
                   let url = URL(string: path) {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if urls.count >= 2 {
                let isFolder = urls[0].hasDirectoryPath
                appState.comparisonMode = isFolder ? .folders : .files
                appState.leftPath = urls[0]
                appState.rightPath = urls[1]
                appState.compare()
            } else if urls.count == 1 {
                let isFolder = urls[0].hasDirectoryPath
                appState.comparisonMode = isFolder ? .folders : .files
                appState.leftPath = urls[0]
            }
        }
    }
}

import SwiftUI

/// File browser pane showing directory contents
struct FilePaneView: View {
    @ObservedObject var pane: PaneState
    @EnvironmentObject var appState: AppState
    
    private var isActive: Bool {
        pane.side == appState.activePaneSide
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Pane header with search
            PaneHeaderView(pane: pane)
            
            // File list
            if pane.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = pane.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        appState.loadPaneContents(pane)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FileListView(pane: pane)
            }
            
            // Pane footer with status
            PaneFooterView(pane: pane)
        }
        .background(isActive ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor))
        .border(isActive ? Color.accentColor : Color.clear, width: 2)
        .onTapGesture {
            appState.activePaneSide = pane.side
        }
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
            Task {
                do {
                    try await FileManagerService.shared.copyItems(urls, to: pane.currentPath) { _ in
                        return .keepBoth
                    }
                    appState.loadPaneContents(pane)
                } catch {
                    appState.showErrorMessage(error.localizedDescription)
                }
            }
        }
    }
}

/// Pane header with search bar
struct PaneHeaderView: View {
    @ObservedObject var pane: PaneState
    
    var body: some View {
        HStack {
            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Filter...", text: $pane.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !pane.searchText.isEmpty {
                    Button(action: { pane.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// File list table view
struct FileListView: View {
    @ObservedObject var pane: PaneState
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Table(pane.filteredItems, selection: $pane.selectedItems) {
            TableColumn("") { item in
                Image(systemName: item.iconName)
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .frame(width: 20)
            }
            .width(24)
            
            TableColumn("Name") { item in
                Text(item.name)
                    .lineLimit(1)
            }
            .width(min: 150)
            
            TableColumn("Size") { item in
                Text(item.formattedSize)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
            .width(70)
            
            TableColumn("Date") { item in
                Text(item.formattedModificationDate)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
            .width(120)
            
            TableColumn("Type") { item in
                Text(item.isDirectory ? "Folder" : item.fileExtension.uppercased())
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
            .width(60)
        }
        .tableStyle(.inset)
        .onKeyPress(.return) {
            handleEnter()
            return .handled
        }
        .onKeyPress(.delete) {
            if !pane.selectedItems.isEmpty {
                appState.showDeleteConfirmation = true
            }
            return .handled
        }
        .contextMenu {
            FileContextMenu(pane: pane)
        }
    }
    
    private func handleEnter() {
        guard let item = pane.selectedItem else { return }
        
        if item.name == ".." {
            pane.goUp()
            appState.loadPaneContents(pane)
        } else if item.isDirectory {
            pane.navigateTo(item.url)
            appState.loadPaneContents(pane)
        } else {
            TerminalManager.shared.openFile(item.url)
        }
    }
}

/// Context menu for files
struct FileContextMenu: View {
    @ObservedObject var pane: PaneState
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            Button("Open") {
                if let item = pane.selectedItem {
                    if item.isDirectory {
                        pane.navigateTo(item.url)
                        appState.loadPaneContents(pane)
                    } else {
                        TerminalManager.shared.openFile(item.url)
                    }
                }
            }
            
            Button("Open With...") {
                // Show open with dialog
            }
            
            Divider()
            
            Button("Copy") {
                appState.copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Button("Cut") {
                appState.cutToClipboard()
            }
            .keyboardShortcut("x", modifiers: .command)
            
            Button("Paste") {
                appState.pasteFromClipboard()
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(appState.clipboard.isEmpty)
            
            Divider()
            
            Button("Rename") {
                appState.showRenameDialog = true
            }
            .disabled(pane.selectedItems.count != 1)
            
            Button("Move to Trash") {
                appState.showDeleteConfirmation = true
            }
            .keyboardShortcut(.delete, modifiers: .command)
            
            Divider()
            
            Button("Get Info") {
                if let item = pane.selectedItem {
                    TerminalManager.shared.showFileInfo(item.url)
                }
            }
            
            Button("Reveal in Finder") {
                if let item = pane.selectedItem {
                    TerminalManager.shared.revealInFinder(item.url)
                }
            }
            
            Divider()
            
            Button("Copy Path") {
                if let item = pane.selectedItem {
                    TerminalManager.shared.copyPathToClipboard(item.url)
                }
            }
            
            Button("Open Terminal Here") {
                TerminalManager.shared.openTerminal(at: pane.currentPath)
            }
            
            Divider()
            
            if ArchiveManager.shared.isArchive(pane.selectedItem?.url ?? URL(fileURLWithPath: "/")) {
                Button("Extract Here") {
                    appState.extractSelectedArchive()
                }
            }
            
            if !pane.selectedItems.isEmpty {
                Menu("Create Archive") {
                    ForEach(ArchiveManager.ArchiveType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            // Create archive
                        }
                    }
                }
            }
        }
    }
}

/// Pane footer with status info
struct PaneFooterView: View {
    @ObservedObject var pane: PaneState
    
    var body: some View {
        HStack {
            // Selection info
            if pane.selectedItems.isEmpty {
                let itemCount = pane.items.contains(where: { $0.name == ".." }) ? pane.items.count - 1 : pane.items.count
                Text("\(max(0, itemCount)) items")
            } else {
                let selectedItems = pane.selectedFileItems
                let totalSize = selectedItems.reduce(0) { $0 + $1.size }
                let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                Text("\(selectedItems.count) selected (\(formattedSize))")
            }
            
            Spacer()
            
            // Free space
            let freeSpace = FileManagerService.shared.availableSpace(at: pane.currentPath)
            Text("Free: \(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file))")
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

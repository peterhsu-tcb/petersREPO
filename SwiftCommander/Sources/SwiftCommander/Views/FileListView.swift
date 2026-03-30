import SwiftUI

/// File list panel view
struct FileListView: View {
    @ObservedObject var panelState: PanelState
    let side: PanelSide
    @EnvironmentObject var appState: AppState
    @State private var lastSelectedId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Path bar
            PathBarView(panelState: panelState, side: side)
            
            Divider()
            
            // Quick filter
            QuickSearchView(panelState: panelState)
            
            Divider()
            
            // Column headers
            ColumnHeaderView(panelState: panelState)
            
            Divider()
            
            // File list
            if panelState.isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if let error = panelState.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if panelState.filteredFiles.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Empty folder")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List(panelState.filteredFiles, selection: $panelState.selectedFiles) { item in
                        FileRowView(item: item, isSelected: panelState.selectedFiles.contains(item.id))
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                handleDoubleClick(item)
                            }
                            .onTapGesture {
                                handleSingleClick(item)
                            }
                            .contextMenu {
                                fileContextMenu(for: item)
                            }
                    }
                    .listStyle(.plain)
                    .onChange(of: panelState.focusedFile) { _, newValue in
                        if let id = newValue {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Panel status bar
            PanelStatusBar(panelState: panelState)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Click Handlers
    
    private func handleSingleClick(_ item: FileItem) {
        appState.focusPanel(side)
        
        if NSEvent.modifierFlags.contains(.command) {
            panelState.toggleSelection(item.id)
        } else if NSEvent.modifierFlags.contains(.shift), let lastId = lastSelectedId {
            panelState.selectRange(from: lastId, to: item.id)
        } else {
            panelState.selectSingle(item.id)
        }
        
        lastSelectedId = item.id
    }
    
    private func handleDoubleClick(_ item: FileItem) {
        if item.isDirectory {
            appState.navigateTo(item.url, panel: side)
        } else {
            appState.openFile(item)
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        Button {
            appState.openFile(item)
        } label: {
            Label("Open", systemImage: "arrow.right.circle")
        }
        
        if !item.isDirectory {
            Button {
                appState.openInEditor(item)
            } label: {
                Label("Open in Editor", systemImage: "pencil")
            }
        }
        
        Divider()
        
        Button {
            appState.copySelectedFiles()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        Button {
            appState.cutSelectedFiles()
        } label: {
            Label("Cut", systemImage: "scissors")
        }
        
        if !appState.clipboard.isEmpty {
            Button {
                appState.pasteFiles()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
        }
        
        Divider()
        
        Button {
            appState.showRenameDialog = true
        } label: {
            Label("Rename", systemImage: "pencil.line")
        }
        
        Button(role: .destructive) {
            appState.showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        Divider()
        
        Button {
            appState.revealInFinder(item)
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }
        
        Button {
            appState.showPropertiesDialog = true
        } label: {
            Label("Properties", systemImage: "info.circle")
        }
    }
}

// MARK: - Path Bar View

struct PathBarView: View {
    @ObservedObject var panelState: PanelState
    let side: PanelSide
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            // Navigation buttons
            HStack(spacing: 2) {
                Button {
                    panelState.navigateBack()
                    appState.refreshPanel(side)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!panelState.canNavigateBack)
                
                Button {
                    panelState.navigateForward()
                    appState.refreshPanel(side)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!panelState.canNavigateForward)
                
                Button {
                    panelState.navigateToParent()
                    appState.refreshPanel(side)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
            }
            
            Divider()
                .frame(height: 16)
            
            // Breadcrumb path
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    let components = pathComponents(for: panelState.currentDirectory)
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(component.name.isEmpty ? "/" : component.name) {
                            appState.navigateTo(component.url, panel: side)
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                    }
                }
            }
            
            Spacer()
            
            // Volume info
            if let space = try? appState.fileOperationsService.diskSpace(at: panelState.currentDirectory) {
                Text("\(space.free.formattedSize) free")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func pathComponents(for url: URL) -> [(name: String, url: URL)] {
        var components: [(name: String, url: URL)] = []
        var currentURL = url
        
        while currentURL.path != "/" {
            components.insert((currentURL.lastPathComponent, currentURL), at: 0)
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        components.insert(("/", URL(fileURLWithPath: "/")), at: 0)
        
        return components
    }
}

// MARK: - Column Header View

struct ColumnHeaderView: View {
    @ObservedObject var panelState: PanelState
    
    var body: some View {
        HStack(spacing: 0) {
            // Name column
            Button {
                toggleSort(.nameAscending, .nameDescending)
            } label: {
                HStack {
                    Text("Name")
                    sortIndicator(for: [.nameAscending, .nameDescending])
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.borderless)
            
            Divider()
            
            // Size column
            Button {
                toggleSort(.sizeAscending, .sizeDescending)
            } label: {
                HStack {
                    Text("Size")
                    sortIndicator(for: [.sizeAscending, .sizeDescending])
                }
            }
            .frame(width: 80, alignment: .trailing)
            .buttonStyle(.borderless)
            
            Divider()
            
            // Date column
            Button {
                toggleSort(.dateAscending, .dateDescending)
            } label: {
                HStack {
                    Text("Date")
                    sortIndicator(for: [.dateAscending, .dateDescending])
                }
            }
            .frame(width: 120, alignment: .leading)
            .buttonStyle(.borderless)
            
            Divider()
            
            // Type column
            Button {
                toggleSort(.typeAscending, .typeDescending)
            } label: {
                HStack {
                    Text("Type")
                    sortIndicator(for: [.typeAscending, .typeDescending])
                }
            }
            .frame(width: 60, alignment: .leading)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .font(.caption)
        .foregroundColor(.secondary)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func toggleSort(_ ascending: SortOrder, _ descending: SortOrder) {
        if panelState.sortOrder == ascending {
            panelState.sortOrder = descending
        } else {
            panelState.sortOrder = ascending
        }
    }
    
    @ViewBuilder
    private func sortIndicator(for orders: [SortOrder]) -> some View {
        if orders.contains(panelState.sortOrder) {
            Image(systemName: panelState.sortOrder.isAscending ? "chevron.up" : "chevron.down")
                .font(.caption2)
        }
    }
}

// MARK: - Panel Status Bar

struct PanelStatusBar: View {
    @ObservedObject var panelState: PanelState
    
    var body: some View {
        HStack {
            Text(panelState.currentDirectory.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            if panelState.showHiddenFiles {
                Text("Hidden: ON")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    FileListView(panelState: PanelState(side: .left), side: .left)
        .environmentObject(AppState())
        .frame(width: 500, height: 600)
}

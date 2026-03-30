import SwiftUI

/// Top toolbar view
struct ToolbarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Navigation buttons
            HStack(spacing: 8) {
                Button {
                    appState.navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Back")
                .disabled(!appState.activePanelState.canNavigateBack)
                
                Button {
                    appState.navigateForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Forward")
                .disabled(!appState.activePanelState.canNavigateForward)
                
                Button {
                    appState.navigateUp()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .help("Up")
                
                Button {
                    appState.navigateToHome()
                } label: {
                    Image(systemName: "house")
                }
                .help("Home")
                
                Button {
                    appState.refreshPanels()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            
            Divider()
                .frame(height: 20)
            
            // Middle - File operations
            HStack(spacing: 8) {
                Button {
                    appState.showCopyDialog = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy to other panel (F5)")
                .disabled(appState.activePanelState.selectedFiles.isEmpty)
                
                Button {
                    appState.showMoveDialog = true
                } label: {
                    Image(systemName: "arrow.right.doc.on.clipboard")
                }
                .help("Move to other panel (F6)")
                .disabled(appState.activePanelState.selectedFiles.isEmpty)
                
                Button {
                    appState.showNewFolderDialog = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Folder (F7)")
                
                Button {
                    appState.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete (F8)")
                .disabled(appState.activePanelState.selectedFiles.isEmpty)
            }
            
            Divider()
                .frame(height: 20)
            
            // View options
            HStack(spacing: 8) {
                Button {
                    appState.toggleHiddenFiles()
                } label: {
                    Image(systemName: appState.activePanelState.showHiddenFiles ? "eye" : "eye.slash")
                }
                .help("Toggle Hidden Files")
                
                Button {
                    appState.showFindDialog = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Find Files")
            }
            
            Spacer()
            
            // Right side - Bookmarks
            Menu {
                ForEach(appState.bookmarkManager.bookmarks) { bookmark in
                    Button {
                        appState.navigateTo(bookmark.url)
                    } label: {
                        Label(bookmark.name, systemImage: bookmark.icon)
                    }
                }
                
                Divider()
                
                Button {
                    appState.bookmarkManager.addBookmark(url: appState.activePanelState.currentDirectory)
                } label: {
                    Label("Add Current Folder", systemImage: "plus")
                }
                
                Button {
                    appState.bookmarkManager.resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Label("Bookmarks", systemImage: "bookmark")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            // Terminal button
            Button {
                appState.openTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .help("Open Terminal Here")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    ToolbarView()
        .environmentObject(AppState())
        .frame(width: 800)
}

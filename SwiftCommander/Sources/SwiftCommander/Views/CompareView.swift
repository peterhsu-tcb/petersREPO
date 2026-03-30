import SwiftUI

/// View for comparing files between left and right panels
struct CompareView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with file names
            CompareHeaderView()
            
            Divider()
            
            // Main content
            if let diffResult = appState.diffResult {
                if diffResult.isIdentical {
                    IdenticalFilesView()
                } else {
                    CompareContentView(diffResult: diffResult)
                }
            } else if appState.isComparing {
                ComparingProgressView()
            } else {
                SelectFilesView()
            }
            
            Divider()
            
            // Footer with actions and statistics
            CompareFooterView()
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert("Error", isPresented: $appState.showCompareError) {
            Button("OK") {
                appState.compareErrorMessage = nil
            }
        } message: {
            Text(appState.compareErrorMessage ?? "An unknown error occurred")
        }
        .alert("Merge Complete", isPresented: $appState.showMergeSuccess) {
            Button("OK") {
                // Re-compare after merge
                appState.compareSelectedFiles()
            }
        } message: {
            Text(appState.mergeSuccessMessage ?? "Merge completed successfully")
        }
    }
}

// MARK: - Compare Header

struct CompareHeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            // Left file
            VStack(alignment: .leading, spacing: 2) {
                Text("Left File")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(appState.compareLeftFile?.lastPathComponent ?? "No file selected")
                    .font(.headline)
                    .lineLimit(1)
                if let url = appState.compareLeftFile {
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 40)
            
            // Right file
            VStack(alignment: .leading, spacing: 2) {
                Text("Right File")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(appState.compareRightFile?.lastPathComponent ?? "No file selected")
                    .font(.headline)
                    .lineLimit(1)
                if let url = appState.compareRightFile {
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Compare Content

struct CompareContentView: View {
    let diffResult: DiffResult
    @EnvironmentObject var appState: AppState
    @State private var selectedChunkIndex: Int?
    
    var body: some View {
        HSplitView {
            // Left panel
            DiffPanelView(
                lines: diffResult.leftLines,
                side: .left,
                selectedChunkIndex: $selectedChunkIndex
            )
            
            // Right panel
            DiffPanelView(
                lines: diffResult.rightLines,
                side: .right,
                selectedChunkIndex: $selectedChunkIndex
            )
        }
    }
}

// MARK: - Diff Panel View

struct DiffPanelView: View {
    let lines: [DiffLine]
    let side: PanelSide
    @Binding var selectedChunkIndex: Int?
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        DiffLineView(line: line, side: side)
                            .id(index)
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// MARK: - Diff Line View

struct DiffLineView: View {
    let line: DiffLine
    let side: PanelSide
    
    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text(line.lineNumber.map { String($0) } ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.horizontal, 4)
            
            Divider()
            
            // Content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
        }
        .background(backgroundColor)
    }
    
    private var textColor: Color {
        switch line.changeType {
        case .unchanged:
            return .primary
        case .added:
            return Color.green
        case .removed:
            return Color.red
        case .modified:
            return Color.orange
        }
    }
    
    private var backgroundColor: Color {
        switch line.changeType {
        case .unchanged:
            return .clear
        case .added:
            return Color.green.opacity(0.1)
        case .removed:
            return Color.red.opacity(0.1)
        case .modified:
            return Color.orange.opacity(0.1)
        }
    }
}

// MARK: - Compare Footer

struct CompareFooterView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack {
            // Statistics
            if let diffResult = appState.diffResult {
                let stats = diffResult.statistics
                HStack(spacing: 16) {
                    StatBadge(label: "Added", count: stats.added, color: .green)
                    StatBadge(label: "Removed", count: stats.removed, color: .red)
                    StatBadge(label: "Modified", count: stats.modified, color: .orange)
                    StatBadge(label: "Unchanged", count: stats.unchanged, color: .secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Refresh") {
                    appState.compareSelectedFiles()
                }
                .disabled(appState.compareLeftFile == nil || appState.compareRightFile == nil)
                
                Menu {
                    Button("Copy Left → Right") {
                        appState.mergeLeftToRight()
                    }
                    .disabled(appState.diffResult == nil || appState.diffResult?.isIdentical == true)
                    
                    Button("Copy Right → Left") {
                        appState.mergeRightToLeft()
                    }
                    .disabled(appState.diffResult == nil || appState.diffResult?.isIdentical == true)
                } label: {
                    Label("Merge", systemImage: "arrow.left.arrow.right")
                }
                .disabled(appState.diffResult == nil || appState.diffResult?.isIdentical == true)
                
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Views

struct IdenticalFilesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("Files are identical")
                .font(.title2)
            Text("No differences found between the two files")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ComparingProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Comparing files...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SelectFilesView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Select files to compare")
                .font(.title2)
            Text("Select one file in each panel, then use Compare from the Tools menu")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if appState.compareLeftFile != nil || appState.compareRightFile != nil {
                Button("Compare Selected Files") {
                    appState.compareSelectedFiles()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.compareLeftFile == nil || appState.compareRightFile == nil)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    CompareView()
        .environmentObject(AppState())
        .frame(width: 1000, height: 700)
}

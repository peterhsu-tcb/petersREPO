import SwiftUI

/// View that displays comparison results based on mode
struct ComparisonView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            StatusBarView()
            
            Divider()
            
            // Main comparison content
            switch appState.comparisonMode {
            case .files:
                if let result = appState.diffResult {
                    FileDiffView(result: result)
                }
            case .folders:
                if let result = appState.folderComparisonResult {
                    FolderComparisonView(result: result)
                }
            }
        }
    }
}

/// Status bar showing comparison summary
struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            // Left side info
            if let leftPath = appState.leftPath {
                Label(leftPath.lastPathComponent, systemImage: "doc")
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Center - summary
            summaryText
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Right side info
            if let rightPath = appState.rightPath {
                Label(rightPath.lastPathComponent, systemImage: "doc")
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var summaryText: some View {
        if let diffResult = appState.diffResult {
            Text(diffResult.statistics.summary)
        } else if let folderResult = appState.folderComparisonResult {
            Text(folderResult.summary)
        } else {
            Text("")
        }
    }
}

/// View for displaying file diff results
struct FileDiffView: View {
    let result: DiffResult
    @EnvironmentObject var appState: AppState
    @State private var scrollPosition: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left file panel
                DiffPanelView(
                    lines: filteredLines(result.leftLines, isLeft: true),
                    pairedLines: filteredLines(result.rightLines, isLeft: false),
                    title: result.leftFile?.lastPathComponent ?? "Left",
                    isLeft: true,
                    width: geometry.size.width / 2
                )
                
                Divider()
                
                // Right file panel
                DiffPanelView(
                    lines: filteredLines(result.rightLines, isLeft: false),
                    pairedLines: filteredLines(result.leftLines, isLeft: true),
                    title: result.rightFile?.lastPathComponent ?? "Right",
                    isLeft: false,
                    width: geometry.size.width / 2
                )
            }
        }
    }
    
    private func filteredLines(_ lines: [DiffLine], isLeft: Bool) -> [DiffLine] {
        if appState.showOnlyDifferences {
            return lines.filter { $0.changeType != .unchanged }
        }
        return lines
    }
}

/// Individual diff panel showing file content
struct DiffPanelView: View {
    let lines: [DiffLine]
    let pairedLines: [DiffLine]
    let title: String
    let isLeft: Bool
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Text("\(lines.count) lines")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let pairedContent = getPairedContent(for: index, line: line)
                        DiffLineView(line: line, pairedLineContent: pairedContent)
                    }
                }
            }
        }
        .frame(width: width)
    }
    
    /// Get the paired line content for character-level diff comparison
    private func getPairedContent(for index: Int, line: DiffLine) -> String? {
        // Only compute character diffs for changed lines
        guard line.changeType != .unchanged else { return nil }
        
        // Get the paired line at the same index if it exists and is also changed
        guard index < pairedLines.count else { return nil }
        let pairedLine = pairedLines[index]
        
        // Return paired content for character comparison
        guard pairedLine.changeType != .unchanged && !pairedLine.content.isEmpty else { return nil }
        
        return pairedLine.content
    }
}

/// Single line in the diff view
struct DiffLineView: View {
    let line: DiffLine
    /// Optional paired line content for computing character diffs on modified lines
    var pairedLineContent: String? = nil
    
    @AppStorage("matchingCharColor") private var matchingCharColor = "blue"
    @AppStorage("differentCharColor") private var differentCharColor = "red"
    
    var body: some View {
        HStack(spacing: 0) {
            // Line number gutter
            Text(line.lineNumber.map { String($0) } ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Change indicator
            Text(changeIndicator)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 16)
            
            // Line content - with character-level highlighting for modified lines
            if line.changeType == .modified || line.changeType == .added || line.changeType == .removed,
               let paired = pairedLineContent,
               !line.content.isEmpty {
                characterDiffText
            } else {
                Text(line.content)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundColor)
    }
    
    @ViewBuilder
    private var characterDiffText: some View {
        let diffs = computeCharacterDiffs()
        if diffs.isEmpty {
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(colorFromName(matchingCharColor))
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(diffs.enumerated()), id: \.offset) { _, diff in
                    Text(String(line.content[diff.range]))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(diff.isChanged ? colorFromName(differentCharColor) : colorFromName(matchingCharColor))
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
        }
    }
    
    private func computeCharacterDiffs() -> [CharacterDiff] {
        guard let paired = pairedLineContent else {
            return []
        }
        
        // Compute character-level diff between this line and its paired line
        let (leftDiffs, rightDiffs) = FileComparisonService.computeCharacterDiffs(
            original: line.changeType == .removed ? line.content : paired,
            modified: line.changeType == .removed ? paired : line.content
        )
        
        // Return the appropriate diffs based on line type
        return line.changeType == .removed ? leftDiffs : rightDiffs
    }
    
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "magenta": return Color(red: 1, green: 0, blue: 1)
        default: return .blue
        }
    }
    
    private var changeIndicator: String {
        switch line.changeType {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        case .modified: return "~"
        }
    }
    
    private var indicatorColor: Color {
        switch line.changeType {
        case .unchanged: return .secondary
        case .added: return .green
        case .removed: return .red
        case .modified: return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch line.changeType {
        case .unchanged: return .clear
        case .added: return Color.green.opacity(0.15)
        case .removed: return Color.red.opacity(0.15)
        case .modified: return Color.orange.opacity(0.15)
        }
    }
}

/// View for displaying folder comparison results
struct FolderComparisonView: View {
    let result: FolderComparisonResult
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            ForEach(filteredItems) { item in
                ComparisonItemRow(item: item, depth: 0)
            }
        }
        .listStyle(.inset)
    }
    
    private var filteredItems: [ComparisonItem] {
        if appState.showOnlyDifferences {
            return result.items.filter { $0.status != .identical }
        }
        return result.items
    }
}

/// Row displaying a comparison item
struct ComparisonItemRow: View {
    let item: ComparisonItem
    let depth: Int
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Expand/collapse for directories
                if item.isDirectory && item.children != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // Icon
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundColor(iconColor)
                
                // Name
                Text(item.name)
                    .fontWeight(item.isDirectory ? .medium : .regular)
                
                Spacer()
                
                // Left side info
                VStack(alignment: .trailing) {
                    Text(item.leftSize)
                        .font(.caption)
                    Text(item.leftDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 120)
                
                // Status
                Label(item.status.description, systemImage: item.status.symbolName)
                    .foregroundColor(statusColor)
                    .frame(width: 100)
                
                // Right side info
                VStack(alignment: .leading) {
                    Text(item.rightSize)
                        .font(.caption)
                    Text(item.rightDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 120)
                
                // Action buttons
                if item.status != .identical {
                    HStack(spacing: 4) {
                        if item.leftItem != nil {
                            Button(action: { copyToRight() }) {
                                Image(systemName: "arrow.right")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy to right")
                        }
                        
                        if item.rightItem != nil {
                            Button(action: { copyToLeft() }) {
                                Image(systemName: "arrow.left")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy to left")
                        }
                    }
                }
            }
            .padding(.leading, CGFloat(depth * 20))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                appState.selectedComparisonItem = item
            }
            .background(appState.selectedComparisonItem?.id == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
            
            // Children
            if isExpanded, let children = item.children {
                ForEach(children) { child in
                    ComparisonItemRow(item: child, depth: depth + 1)
                }
            }
        }
    }
    
    private var iconColor: Color {
        switch item.status {
        case .identical: return .secondary
        case .different: return .orange
        case .leftOnly: return .blue
        case .rightOnly: return .green
        case .error: return .red
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .identical: return .green
        case .different: return .orange
        case .leftOnly: return .blue
        case .rightOnly: return .purple
        case .error: return .red
        }
    }
    
    private func copyToRight() {
        guard let source = item.leftItem?.url,
              let rightFolder = appState.rightPath else { return }
        
        let destination = rightFolder.appendingPathComponent(item.name)
        
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            appState.refresh()
        } catch {
            appState.errorMessage = "Copy failed: \(error.localizedDescription)"
        }
    }
    
    private func copyToLeft() {
        guard let source = item.rightItem?.url,
              let leftFolder = appState.leftPath else { return }
        
        let destination = leftFolder.appendingPathComponent(item.name)
        
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            appState.refresh()
        } catch {
            appState.errorMessage = "Copy failed: \(error.localizedDescription)"
        }
    }
}

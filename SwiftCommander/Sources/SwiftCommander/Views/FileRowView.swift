import SwiftUI

/// Individual file row in the file list
struct FileRowView: View {
    let item: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Icon and name
            HStack(spacing: 8) {
                // File icon
                Image(systemName: item.iconName)
                    .foregroundColor(iconColor)
                    .frame(width: 16)
                
                // File name
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                // Symbolic link indicator
                if item.isSymbolicLink {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
            
            // Size
            Text(item.formattedSize)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            // Date
            Text(item.formattedDate)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
                .padding(.leading, 8)
            
            // Extension/Type
            Text(item.isDirectory ? "DIR" : item.fileExtension.uppercased())
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
    
    private var iconColor: Color {
        if item.isDirectory {
            return .blue
        }
        return Color.forFileType(item.fileType)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        FileRowView(
            item: FileItem(
                url: URL(fileURLWithPath: "/Users/test/Documents"),
                isDirectory: true,
                size: 0,
                modificationDate: Date(),
                creationDate: Date(),
                isHidden: false,
                isSymbolicLink: false,
                permissions: FilePermissions(posix: 0o755)
            ),
            isSelected: false
        )
        
        FileRowView(
            item: FileItem(
                url: URL(fileURLWithPath: "/Users/test/example.swift"),
                isDirectory: false,
                size: 12345,
                modificationDate: Date(),
                creationDate: Date(),
                isHidden: false,
                isSymbolicLink: false,
                permissions: FilePermissions(posix: 0o644)
            ),
            isSelected: true
        )
        
        FileRowView(
            item: FileItem(
                url: URL(fileURLWithPath: "/Users/test/archive.zip"),
                isDirectory: false,
                size: 1024 * 1024 * 5,
                modificationDate: Date(),
                creationDate: Date(),
                isHidden: false,
                isSymbolicLink: false,
                permissions: FilePermissions(posix: 0o644)
            ),
            isSelected: false
        )
    }
    .frame(width: 600)
}

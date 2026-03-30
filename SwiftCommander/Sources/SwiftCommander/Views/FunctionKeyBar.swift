import SwiftUI

/// Function key bar at the bottom (Total Commander style)
struct FunctionKeyBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DefaultCommands.functionKeyCommands) { command in
                FunctionKeyButton(command: command) {
                    appState.executeCommand(command.action)
                }
                
                if command.id != .f10 {
                    Divider()
                }
            }
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// Individual function key button
struct FunctionKeyButton: View {
    let command: CommandDefinition
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(command.id.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(command.label)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    FunctionKeyBar()
        .environmentObject(AppState())
        .frame(width: 1000)
}

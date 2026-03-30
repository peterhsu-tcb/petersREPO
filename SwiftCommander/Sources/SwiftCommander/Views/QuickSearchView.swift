import SwiftUI

/// Quick search/filter bar for file panel
struct QuickSearchView: View {
    @ObservedObject var panelState: PanelState
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Quick filter...", text: $panelState.filterText)
                .textFieldStyle(.plain)
                .focused($isFocused)
            
            if !panelState.filterText.isEmpty {
                Button {
                    panelState.filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("\(panelState.filteredFiles.count) matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    QuickSearchView(panelState: PanelState(side: .left))
        .frame(width: 400)
}

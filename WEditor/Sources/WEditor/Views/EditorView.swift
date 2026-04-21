import SwiftUI

/// Container view that holds the editor with gutter and minimap
struct EditorContainerView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if document.isHTML && document.htmlEditMode == .visual {
                // Full visual/WYSIWYG editor
                #if canImport(WebKit)
                HTMLVisualEditorView(document: document)
                #else
                sourceEditorView
                #endif
            } else if document.isHTML && document.htmlEditMode == .split {
                // Split view: source on left, preview on right
                #if canImport(WebKit)
                HSplitView {
                    sourceEditorView
                        .frame(minWidth: 300)
                    HTMLVisualEditorView(document: document)
                        .frame(minWidth: 300)
                }
                #else
                sourceEditorView
                #endif
            } else {
                // Source code editor (default for non-HTML or source mode)
                sourceEditorView
            }
        }
    }
    
    @ViewBuilder
    private var sourceEditorView: some View {
        HStack(spacing: 0) {
            // Gutter (line numbers)
            if settings.showLineNumbers {
                GutterView(document: document)
            }
            
            // Main editor
            EditorView(document: document)
            
            // Mini map
            if settings.showMiniMap {
                MiniMapView(document: document)
            }
        }
    }
}

/// Main text editor view using NSTextView wrapper
struct EditorView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Column edit mode indicator
            if appState.isColumnEditMode {
                HStack {
                    Image(systemName: "rectangle.split.3x1")
                        .foregroundColor(.accentColor)
                    Text("Column Edit Mode")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text("(Arrow keys to select, Delete/Type to edit)")
                        .font(.system(size: 11))
                        .foregroundColor(settings.currentTheme.textColor.opacity(0.5))
                    Spacer()
                    Button("Exit (⌘L)") {
                        appState.isColumnEditMode = false
                        document.columnSelection = nil
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(settings.currentTheme.gutterBackgroundColor)
            }
            
            // Editor content
            EditorTextView(document: document)
                .background(settings.currentTheme.backgroundColor)
        }
    }
}

/// SwiftUI wrapper for the text editing area
struct EditorTextView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if canImport(AppKit)
        EditableTextView(document: document, settings: settings, appState: appState)
            .background(settings.currentTheme.backgroundColor)
        #else
        Text("Editor unavailable on this platform")
            .foregroundColor(settings.currentTheme.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(settings.currentTheme.backgroundColor)
        #endif
    }
}

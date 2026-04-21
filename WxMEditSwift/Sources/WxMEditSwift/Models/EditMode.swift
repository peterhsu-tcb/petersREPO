import Foundation

/// The three editing modes wxMEdit is known for.
///
/// - text:   conventional character-stream editing
/// - column: rectangular block editing (a.k.a. "column mode")
/// - hex:    raw byte editing displayed as a hex grid + ASCII pane
public enum EditMode: String, CaseIterable, Identifiable, Codable {
    case text   = "Text"
    case column = "Column"
    case hex    = "Hex"

    public var id: String { rawValue }
}

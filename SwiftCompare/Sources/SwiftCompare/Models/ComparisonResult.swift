import Foundation

/// Represents the comparison status of items in folder comparison
enum ComparisonStatus: Equatable {
    case identical
    case different
    case leftOnly
    case rightOnly
    case error(String)
    
    var description: String {
        switch self {
        case .identical: return "Identical"
        case .different: return "Different"
        case .leftOnly: return "Left Only"
        case .rightOnly: return "Right Only"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var symbolName: String {
        switch self {
        case .identical: return "equal.circle.fill"
        case .different: return "exclamationmark.triangle.fill"
        case .leftOnly: return "arrow.left.circle.fill"
        case .rightOnly: return "arrow.right.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

/// Represents a pair of items being compared in folder comparison
struct ComparisonItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let leftItem: FileItem?
    let rightItem: FileItem?
    let status: ComparisonStatus
    let isDirectory: Bool
    var children: [ComparisonItem]?
    var isExpanded: Bool
    
    init(
        name: String,
        leftItem: FileItem?,
        rightItem: FileItem?,
        status: ComparisonStatus,
        isDirectory: Bool,
        children: [ComparisonItem]? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.status = status
        self.isDirectory = isDirectory
        self.children = children
        self.isExpanded = false
    }
    
    /// Returns the file size for display
    var leftSize: String {
        leftItem?.formattedSize ?? "--"
    }
    
    var rightSize: String {
        rightItem?.formattedSize ?? "--"
    }
    
    /// Returns the modification date for display
    var leftDate: String {
        leftItem?.formattedModificationDate ?? "--"
    }
    
    var rightDate: String {
        rightItem?.formattedModificationDate ?? "--"
    }
    
    static func == (lhs: ComparisonItem, rhs: ComparisonItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Result of comparing two folders
struct FolderComparisonResult: Equatable {
    let leftFolder: URL
    let rightFolder: URL
    let items: [ComparisonItem]
    let totalItems: Int
    let identicalItems: Int
    let differentItems: Int
    let leftOnlyItems: Int
    let rightOnlyItems: Int
    
    init(
        leftFolder: URL,
        rightFolder: URL,
        items: [ComparisonItem]
    ) {
        self.leftFolder = leftFolder
        self.rightFolder = rightFolder
        self.items = items
        
        var total = 0
        var identical = 0
        var different = 0
        var leftOnly = 0
        var rightOnly = 0
        
        func countItems(_ items: [ComparisonItem]) {
            for item in items {
                total += 1
                switch item.status {
                case .identical: identical += 1
                case .different: different += 1
                case .leftOnly: leftOnly += 1
                case .rightOnly: rightOnly += 1
                case .error: break
                }
                if let children = item.children {
                    countItems(children)
                }
            }
        }
        
        countItems(items)
        
        self.totalItems = total
        self.identicalItems = identical
        self.differentItems = different
        self.leftOnlyItems = leftOnly
        self.rightOnlyItems = rightOnly
    }
    
    var summary: String {
        var parts: [String] = []
        parts.append("\(totalItems) items")
        if identicalItems > 0 { parts.append("\(identicalItems) identical") }
        if differentItems > 0 { parts.append("\(differentItems) different") }
        if leftOnlyItems > 0 { parts.append("\(leftOnlyItems) left only") }
        if rightOnlyItems > 0 { parts.append("\(rightOnlyItems) right only") }
        return parts.joined(separator: ", ")
    }
}

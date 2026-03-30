import Foundation

/// Extension for FileManager utilities
extension FileManager {
    /// Get the size of a directory recursively
    func directorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        
        guard let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  resourceValues.isDirectory == false,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            size += Int64(fileSize)
        }
        
        return size
    }
    
    /// Check if a path is readable
    func isReadable(at url: URL) -> Bool {
        return self.isReadableFile(atPath: url.path)
    }
    
    /// Check if a path is writable
    func isWritable(at url: URL) -> Bool {
        return self.isWritableFile(atPath: url.path)
    }
}

/// Extension for String utilities
extension String {
    /// Normalize line endings to Unix style
    var normalizedLineEndings: String {
        return self.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
    
    /// Remove leading and trailing whitespace from each line
    var trimmedLines: String {
        return self.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }
    
    /// Check if string is likely binary content
    var isBinaryContent: Bool {
        return self.unicodeScalars.contains { scalar in
            scalar.value < 32 && scalar.value != 9 && scalar.value != 10 && scalar.value != 13
        }
    }
}

/// Extension for URL utilities
extension URL {
    /// Get relative path from base URL
    func relativePath(from base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let selfPath = self.standardizedFileURL.path
        
        if selfPath.hasPrefix(basePath) {
            var relativePath = String(selfPath.dropFirst(basePath.count))
            if relativePath.hasPrefix("/") {
                relativePath = String(relativePath.dropFirst())
            }
            return relativePath
        }
        
        return selfPath
    }
    
    /// Check if this URL points to a hidden file
    var isHidden: Bool {
        return (try? resourceValues(forKeys: [.isHiddenKey]))?.isHidden ?? false
    }
}

/// Thread-safe array for collecting results
class ThreadSafeArray<T> {
    private var array: [T] = []
    private let queue = DispatchQueue(label: "com.swiftcompare.threadSafeArray", attributes: .concurrent)
    
    func append(_ element: T) {
        queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }
    
    func getAll() -> [T] {
        var result: [T] = []
        queue.sync {
            result = self.array
        }
        return result
    }
}

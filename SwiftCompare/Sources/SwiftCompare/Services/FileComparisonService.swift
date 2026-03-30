import Foundation

/// Service for comparing text files using Myers' diff algorithm
class FileComparisonService {
    
    /// Compare two text files and return a diff result
    func compareFiles(leftURL: URL?, rightURL: URL?) -> DiffResult {
        let leftContent: String?
        let rightContent: String?
        var leftExists = false
        var rightExists = false
        
        if let left = leftURL {
            leftContent = try? String(contentsOf: left, encoding: .utf8)
            leftExists = FileManager.default.fileExists(atPath: left.path)
        } else {
            leftContent = nil
        }
        
        if let right = rightURL {
            rightContent = try? String(contentsOf: right, encoding: .utf8)
            rightExists = FileManager.default.fileExists(atPath: right.path)
        } else {
            rightContent = nil
        }
        
        return compareStrings(
            left: leftContent ?? "",
            right: rightContent ?? "",
            leftFile: leftURL,
            rightFile: rightURL,
            leftExists: leftExists,
            rightExists: rightExists
        )
    }
    
    /// Compare two strings and return a diff result
    func compareStrings(
        left: String,
        right: String,
        leftFile: URL? = nil,
        rightFile: URL? = nil,
        leftExists: Bool = true,
        rightExists: Bool = true
    ) -> DiffResult {
        let leftLines = left.components(separatedBy: .newlines)
        let rightLines = right.components(separatedBy: .newlines)
        
        let lcs = longestCommonSubsequence(leftLines, rightLines)
        let (diffLeftLines, diffRightLines, chunks) = buildDiff(leftLines, rightLines, lcs)
        
        let isIdentical = left == right
        
        return DiffResult(
            leftFile: leftFile,
            rightFile: rightFile,
            chunks: chunks,
            leftLines: diffLeftLines,
            rightLines: diffRightLines,
            isIdentical: isIdentical,
            leftFileExists: leftExists,
            rightFileExists: rightExists
        )
    }
    
    /// Compute the longest common subsequence using dynamic programming
    private func longestCommonSubsequence(_ left: [String], _ right: [String]) -> [[Int]] {
        let m = left.count
        let n = right.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if left[i - 1] == right[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        return dp
    }
    
    /// Build the diff output from LCS table
    private func buildDiff(
        _ left: [String],
        _ right: [String],
        _ lcs: [[Int]]
    ) -> ([DiffLine], [DiffLine], [DiffChunk]) {
        var leftResult: [DiffLine] = []
        var rightResult: [DiffLine] = []
        var chunks: [DiffChunk] = []
        
        var i = left.count
        var j = right.count
        var tempLeft: [(Int, String, DiffChangeType)] = []
        var tempRight: [(Int, String, DiffChangeType)] = []
        
        // Trace back through the LCS table
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && left[i - 1] == right[j - 1] {
                // Lines match
                tempLeft.insert((i, left[i - 1], .unchanged), at: 0)
                tempRight.insert((j, right[j - 1], .unchanged), at: 0)
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
                // Line added on right
                tempLeft.insert((0, "", .unchanged), at: 0)
                tempRight.insert((j, right[j - 1], .added), at: 0)
                j -= 1
            } else if i > 0 {
                // Line removed from left
                tempLeft.insert((i, left[i - 1], .removed), at: 0)
                tempRight.insert((0, "", .unchanged), at: 0)
                i -= 1
            }
        }
        
        // Convert to DiffLine objects and build aligned output
        var leftLineNum = 1
        var rightLineNum = 1
        var chunkLeftLines: [DiffLine] = []
        var chunkRightLines: [DiffLine] = []
        var inChunk = false
        var chunkLeftStart = 0
        var chunkRightStart = 0
        
        for idx in 0..<tempLeft.count {
            let (_, leftContent, leftType) = tempLeft[idx]
            let (_, rightContent, rightType) = tempRight[idx]
            
            if leftType == .unchanged && rightType == .unchanged {
                // Save any pending chunk
                if inChunk && (!chunkLeftLines.isEmpty || !chunkRightLines.isEmpty) {
                    chunks.append(DiffChunk(
                        leftStartLine: chunkLeftStart,
                        leftLineCount: chunkLeftLines.count,
                        rightStartLine: chunkRightStart,
                        rightLineCount: chunkRightLines.count,
                        leftLines: chunkLeftLines,
                        rightLines: chunkRightLines
                    ))
                    chunkLeftLines = []
                    chunkRightLines = []
                    inChunk = false
                }
                
                leftResult.append(DiffLine(lineNumber: leftLineNum, content: leftContent, changeType: .unchanged))
                rightResult.append(DiffLine(lineNumber: rightLineNum, content: rightContent, changeType: .unchanged))
                leftLineNum += 1
                rightLineNum += 1
            } else {
                if !inChunk {
                    inChunk = true
                    chunkLeftStart = leftLineNum
                    chunkRightStart = rightLineNum
                }
                
                if leftType == .removed {
                    let line = DiffLine(lineNumber: leftLineNum, content: leftContent, changeType: .removed)
                    leftResult.append(line)
                    chunkLeftLines.append(line)
                    leftLineNum += 1
                    // Add placeholder on right side
                    rightResult.append(DiffLine(lineNumber: nil, content: "", changeType: .unchanged))
                }
                
                if rightType == .added {
                    let line = DiffLine(lineNumber: rightLineNum, content: rightContent, changeType: .added)
                    rightResult.append(line)
                    chunkRightLines.append(line)
                    rightLineNum += 1
                    // Add placeholder on left side if not already added
                    if leftType != .removed {
                        leftResult.append(DiffLine(lineNumber: nil, content: "", changeType: .unchanged))
                    }
                }
            }
        }
        
        // Don't forget the last chunk
        if inChunk && (!chunkLeftLines.isEmpty || !chunkRightLines.isEmpty) {
            chunks.append(DiffChunk(
                leftStartLine: chunkLeftStart,
                leftLineCount: chunkLeftLines.count,
                rightStartLine: chunkRightStart,
                rightLineCount: chunkRightLines.count,
                leftLines: chunkLeftLines,
                rightLines: chunkRightLines
            ))
        }
        
        return (leftResult, rightResult, chunks)
    }
    
    /// Check if two files are binary files
    func isBinaryFile(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return false
        }
        
        // Check for null bytes in the first 8000 bytes (common heuristic)
        let checkLength = min(data.count, 8000)
        for i in 0..<checkLength {
            if data[i] == 0 {
                return true
            }
        }
        
        return false
    }
    
    /// Compare binary files by content
    func compareBinaryFiles(leftURL: URL, rightURL: URL) -> Bool {
        guard let leftData = try? Data(contentsOf: leftURL),
              let rightData = try? Data(contentsOf: rightURL) else {
            return false
        }
        return leftData == rightData
    }
}

import Foundation
import SwiftUI

/// Supported syntax highlighting languages
enum SyntaxLanguage: String, CaseIterable, Identifiable {
    case plainText = "Plain Text"
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case java = "Java"
    case cSharp = "C#"
    case cpp = "C++"
    case c = "C"
    case objectiveC = "Objective-C"
    case ruby = "Ruby"
    case go = "Go"
    case rust = "Rust"
    case php = "PHP"
    case html = "HTML"
    case css = "CSS"
    case json = "JSON"
    case xml = "XML"
    case yaml = "YAML"
    case markdown = "Markdown"
    case sql = "SQL"
    case shell = "Shell"
    case perl = "Perl"
    case lua = "Lua"
    case r = "R"
    case kotlin = "Kotlin"
    case scala = "Scala"
    case dart = "Dart"
    case elixir = "Elixir"
    case haskell = "Haskell"
    case toml = "TOML"
    case ini = "INI"
    case dockerfile = "Dockerfile"
    case makefile = "Makefile"
    
    var id: String { rawValue }
    
    /// Detect language from file extension
    static func detect(from url: URL) -> SyntaxLanguage {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        
        // Check special filenames first
        switch name {
        case "dockerfile": return .dockerfile
        case "makefile", "gnumakefile": return .makefile
        case "gemfile", "rakefile": return .ruby
        case "podfile": return .ruby
        default: break
        }
        
        switch ext {
        case "swift": return .swift
        case "py", "pyw", "pyi": return .python
        case "js", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "java": return .java
        case "cs": return .cSharp
        case "cpp", "cc", "cxx", "hpp", "hxx", "h": return .cpp
        case "c": return .c
        case "m", "mm": return .objectiveC
        case "rb", "rake": return .ruby
        case "go": return .go
        case "rs": return .rust
        case "php": return .php
        case "html", "htm", "xhtml": return .html
        case "css", "scss", "less", "sass": return .css
        case "json", "jsonl": return .json
        case "xml", "xsl", "xslt", "svg", "plist": return .xml
        case "yml", "yaml": return .yaml
        case "md", "markdown", "mdown": return .markdown
        case "sql": return .sql
        case "sh", "bash", "zsh", "fish": return .shell
        case "pl", "pm": return .perl
        case "lua": return .lua
        case "r", "rmd": return .r
        case "kt", "kts": return .kotlin
        case "scala", "sc": return .scala
        case "dart": return .dart
        case "ex", "exs": return .elixir
        case "hs", "lhs": return .haskell
        case "toml": return .toml
        case "ini", "cfg", "conf": return .ini
        case "txt", "log", "text": return .plainText
        default: return .plainText
        }
    }
}

/// A syntax highlighting rule
struct SyntaxRule {
    let pattern: String
    let tokenType: TokenType
    let options: NSRegularExpression.Options
    
    init(pattern: String, tokenType: TokenType, options: NSRegularExpression.Options = []) {
        self.pattern = pattern
        self.tokenType = tokenType
        self.options = options
    }
}

/// Token types for syntax highlighting
enum TokenType: String, CaseIterable {
    case keyword
    case type
    case string
    case number
    case comment
    case preprocessor
    case `operator`
    case function
    case variable
    case constant
    case attribute
    case tag
    case tagAttribute
    case escape
    case regex
    case heading
    case link
    case bold
    case italic
    case plain
}

/// Syntax definition containing rules for a language
struct SyntaxDefinition {
    let language: SyntaxLanguage
    let rules: [SyntaxRule]
    let multiLineCommentStart: String?
    let multiLineCommentEnd: String?
    let singleLineComment: String?
    let stringDelimiters: [String]
    
    /// Get syntax definition for a language
    static func definition(for language: SyntaxLanguage) -> SyntaxDefinition {
        switch language {
        case .swift: return swiftDefinition
        case .python: return pythonDefinition
        case .javascript, .typescript: return javascriptDefinition
        case .java: return javaDefinition
        case .cSharp: return cSharpDefinition
        case .cpp, .c, .objectiveC: return cppDefinition
        case .ruby: return rubyDefinition
        case .go: return goDefinition
        case .rust: return rustDefinition
        case .php: return phpDefinition
        case .html: return htmlDefinition
        case .css: return cssDefinition
        case .json: return jsonDefinition
        case .xml: return xmlDefinition
        case .yaml: return yamlDefinition
        case .markdown: return markdownDefinition
        case .sql: return sqlDefinition
        case .shell: return shellDefinition
        case .perl: return perlDefinition
        case .lua: return luaDefinition
        case .r: return rDefinition
        case .kotlin: return kotlinDefinition
        case .scala: return scalaDefinition
        case .dart: return dartDefinition
        case .elixir: return elixirDefinition
        case .haskell: return haskellDefinition
        case .toml: return tomlDefinition
        case .ini: return iniDefinition
        case .dockerfile: return dockerfileDefinition
        case .makefile: return makefileDefinition
        case .plainText: return plainTextDefinition
        }
    }
    
    // MARK: - Language Definitions
    
    static let plainTextDefinition = SyntaxDefinition(
        language: .plainText,
        rules: [],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: nil,
        stringDelimiters: []
    )
    
    static let swiftDefinition = SyntaxDefinition(
        language: .swift,
        rules: [
            SyntaxRule(pattern: "\\b(import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|for|while|repeat|return|break|continue|throw|throws|rethrows|try|catch|defer|do|in|where|is|as|self|Self|super|init|deinit|subscript|typealias|associatedtype|static|override|final|lazy|weak|unowned|mutating|nonmutating|convenience|required|optional|dynamic|indirect|async|await|actor|nonisolated|isolated|some|any|consuming|borrowing|inout|open|public|internal|fileprivate|private)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(Int|String|Bool|Double|Float|Array|Dictionary|Set|Optional|Any|AnyObject|Void|Never|Character|UInt|Int8|Int16|Int32|Int64|UInt8|UInt16|UInt32|UInt64|Float16|Float32|Float64|CGFloat|URL|Data|Date|UUID|Error|Result|Codable|Encodable|Decodable|Hashable|Equatable|Comparable|Identifiable|ObservableObject|Published|StateObject|State|Binding|Environment|EnvironmentObject)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(true|false|nil)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "#\\w+\\b", tokenType: .preprocessor),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\""]
    )
    
    static let pythonDefinition = SyntaxDefinition(
        language: .python,
        rules: [
            SyntaxRule(pattern: "\\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|match|case)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(int|float|str|bool|list|dict|tuple|set|frozenset|bytes|bytearray|memoryview|complex|range|type|object|None|True|False|Ellipsis|NotImplemented)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(True|False|None)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            SyntaxRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'", "\"\"\"", "'''"]
    )
    
    static let javascriptDefinition = SyntaxDefinition(
        language: .javascript,
        rules: [
            SyntaxRule(pattern: "\\b(break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|function|if|import|in|instanceof|let|new|of|return|super|switch|this|throw|try|typeof|var|void|while|with|yield|async|await|static|get|set|from|as)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(Array|Boolean|Date|Error|Function|JSON|Map|Math|Number|Object|Promise|Proxy|RegExp|Set|String|Symbol|WeakMap|WeakSet|BigInt|console|document|window|globalThis|undefined|NaN|Infinity)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(true|false|null|undefined|NaN|Infinity)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "`(?:[^`\\\\]|\\\\.)*`", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "=>", tokenType: .operator),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "'", "`"]
    )
    
    static let javaDefinition = SyntaxDefinition(
        language: .java,
        rules: [
            SyntaxRule(pattern: "\\b(abstract|assert|boolean|break|byte|case|catch|char|class|continue|default|do|double|else|enum|extends|final|finally|float|for|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|var|void|volatile|while|record|sealed|permits|yield)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(String|Integer|Boolean|Double|Float|Long|Short|Byte|Character|Object|Class|System|List|ArrayList|Map|HashMap|Set|HashSet|Optional|Stream|Collection|Collections|Arrays|Math|Thread|Runnable|Exception|RuntimeException)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(true|false|null)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?[fFdDlL]?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "'"]
    )
    
    static let cSharpDefinition = SyntaxDefinition(
        language: .cSharp,
        rules: [
            SyntaxRule(pattern: "\\b(abstract|as|base|bool|break|byte|case|catch|char|checked|class|const|continue|decimal|default|delegate|do|double|else|enum|event|explicit|extern|false|finally|fixed|float|for|foreach|goto|if|implicit|in|int|interface|internal|is|lock|long|namespace|new|null|object|operator|out|override|params|private|protected|public|readonly|record|ref|return|sbyte|sealed|short|sizeof|stackalloc|static|string|struct|switch|this|throw|true|try|typeof|uint|ulong|unchecked|unsafe|ushort|using|var|virtual|void|volatile|while|async|await|dynamic|nameof|when|with|init|required)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|null)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?[fFdDmM]?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "@\"(?:[^\"]|\"\")*\"", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "#\\w+", tokenType: .preprocessor),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\""]
    )
    
    static let cppDefinition = SyntaxDefinition(
        language: .cpp,
        rules: [
            SyntaxRule(pattern: "\\b(alignas|alignof|and|and_eq|asm|auto|bitand|bitor|bool|break|case|catch|char|char8_t|char16_t|char32_t|class|compl|concept|const|consteval|constexpr|constinit|const_cast|continue|co_await|co_return|co_yield|decltype|default|delete|do|double|dynamic_cast|else|enum|explicit|export|extern|float|for|friend|goto|if|inline|int|long|mutable|namespace|new|noexcept|not|not_eq|nullptr|operator|or|or_eq|private|protected|public|register|reinterpret_cast|requires|return|short|signed|sizeof|static|static_assert|static_cast|struct|switch|template|this|thread_local|throw|try|typedef|typeid|typename|union|unsigned|using|virtual|void|volatile|wchar_t|while|xor|xor_eq)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|nullptr|NULL)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?[fFlLuU]*\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "#\\s*(include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma|error|warning|line)\\b.*$", tokenType: .preprocessor, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "'"]
    )
    
    static let rubyDefinition = SyntaxDefinition(
        language: .ruby,
        rules: [
            SyntaxRule(pattern: "\\b(alias|and|begin|break|case|class|def|defined\\?|do|else|elsif|end|ensure|false|for|if|in|module|next|nil|not|or|redo|rescue|retry|return|self|super|then|true|undef|unless|until|when|while|yield|require|require_relative|include|extend|prepend|attr_reader|attr_writer|attr_accessor|private|protected|public|raise|puts|print|p)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|nil|self)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: ":\\w+", tokenType: .constant),
            SyntaxRule(pattern: "@\\w+", tokenType: .variable),
        ],
        multiLineCommentStart: "=begin",
        multiLineCommentEnd: "=end",
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let goDefinition = SyntaxDefinition(
        language: .go,
        rules: [
            SyntaxRule(pattern: "\\b(break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(bool|byte|complex64|complex128|error|float32|float64|int|int8|int16|int32|int64|rune|string|uint|uint8|uint16|uint32|uint64|uintptr|any|comparable)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(true|false|nil|iota)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "`[^`]*`", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "`"]
    )
    
    static let rustDefinition = SyntaxDefinition(
        language: .rust,
        rules: [
            SyntaxRule(pattern: "\\b(as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while|abstract|become|box|do|final|macro|override|priv|try|typeof|unsized|virtual|yield)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Box|Rc|Arc|Option|Result|Some|None|Ok|Err)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(true|false)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "#\\[.*?\\]", tokenType: .attribute),
            SyntaxRule(pattern: "\\b\\w+!", tokenType: .function),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\""]
    )
    
    static let phpDefinition = SyntaxDefinition(
        language: .php,
        rules: [
            SyntaxRule(pattern: "\\b(abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|die|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|fn|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|match|namespace|new|or|print|private|protected|public|readonly|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|null|TRUE|FALSE|NULL)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\$\\w+", tokenType: .variable),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "'"]
    )
    
    static let htmlDefinition = SyntaxDefinition(
        language: .html,
        rules: [
            SyntaxRule(pattern: "</?\\w+", tokenType: .tag),
            SyntaxRule(pattern: "/?>", tokenType: .tag),
            SyntaxRule(pattern: "\\b\\w+(?=\\s*=)", tokenType: .tagAttribute),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "&\\w+;", tokenType: .escape),
        ],
        multiLineCommentStart: "<!--",
        multiLineCommentEnd: "-->",
        singleLineComment: nil,
        stringDelimiters: ["\"", "'"]
    )
    
    static let cssDefinition = SyntaxDefinition(
        language: .css,
        rules: [
            SyntaxRule(pattern: "\\b(align-content|align-items|align-self|animation|background|border|bottom|box-shadow|clear|clip|color|content|cursor|display|flex|float|font|grid|height|justify-content|left|letter-spacing|line-height|list-style|margin|max-height|max-width|min-height|min-width|opacity|order|outline|overflow|padding|position|resize|right|text-align|text-decoration|text-transform|top|transform|transition|vertical-align|visibility|white-space|width|word-break|word-wrap|z-index)\\s*:", tokenType: .keyword),
            SyntaxRule(pattern: "[.#]\\w[\\w-]*", tokenType: .type),
            SyntaxRule(pattern: "@\\w+", tokenType: .preprocessor),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|pt|cm|mm|in)?\\b", tokenType: .number),
            SyntaxRule(pattern: "#[0-9a-fA-F]{3,8}\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: nil,
        stringDelimiters: ["\"", "'"]
    )
    
    static let jsonDefinition = SyntaxDefinition(
        language: .json,
        rules: [
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"\\s*:", tokenType: .keyword),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "\\b(true|false|null)\\b", tokenType: .constant),
            SyntaxRule(pattern: "-?\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", tokenType: .number),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: nil,
        stringDelimiters: ["\""]
    )
    
    static let xmlDefinition = SyntaxDefinition(
        language: .xml,
        rules: [
            SyntaxRule(pattern: "<[?!]?/?\\w[\\w:.]*", tokenType: .tag),
            SyntaxRule(pattern: "/?>|\\?>", tokenType: .tag),
            SyntaxRule(pattern: "\\b[\\w:]+(?=\\s*=)", tokenType: .tagAttribute),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "&\\w+;", tokenType: .escape),
        ],
        multiLineCommentStart: "<!--",
        multiLineCommentEnd: "-->",
        singleLineComment: nil,
        stringDelimiters: ["\"", "'"]
    )
    
    static let yamlDefinition = SyntaxDefinition(
        language: .yaml,
        rules: [
            SyntaxRule(pattern: "^\\s*[\\w.-]+\\s*:", tokenType: .keyword, options: .anchorsMatchLines),
            SyntaxRule(pattern: "\\b(true|false|yes|no|on|off|null|~)\\b", tokenType: .constant, options: .caseInsensitive),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "---", tokenType: .preprocessor),
            SyntaxRule(pattern: "\\.\\.\\.", tokenType: .preprocessor),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let markdownDefinition = SyntaxDefinition(
        language: .markdown,
        rules: [
            SyntaxRule(pattern: "^#{1,6}\\s.*$", tokenType: .heading, options: .anchorsMatchLines),
            SyntaxRule(pattern: "\\*\\*[^*]+\\*\\*", tokenType: .bold),
            SyntaxRule(pattern: "__[^_]+__", tokenType: .bold),
            SyntaxRule(pattern: "\\*[^*]+\\*", tokenType: .italic),
            SyntaxRule(pattern: "_[^_]+_", tokenType: .italic),
            SyntaxRule(pattern: "`[^`]+`", tokenType: .string),
            SyntaxRule(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", tokenType: .link),
            SyntaxRule(pattern: "^\\s*[-*+]\\s", tokenType: .keyword, options: .anchorsMatchLines),
            SyntaxRule(pattern: "^\\s*\\d+\\.\\s", tokenType: .keyword, options: .anchorsMatchLines),
            SyntaxRule(pattern: "^>.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: nil,
        stringDelimiters: ["`"]
    )
    
    static let sqlDefinition = SyntaxDefinition(
        language: .sql,
        rules: [
            SyntaxRule(pattern: "\\b(SELECT|FROM|WHERE|AND|OR|NOT|IN|EXISTS|BETWEEN|LIKE|IS|NULL|ORDER|BY|GROUP|HAVING|JOIN|INNER|LEFT|RIGHT|OUTER|CROSS|ON|AS|UNION|ALL|DISTINCT|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|ALTER|DROP|INDEX|VIEW|PROCEDURE|FUNCTION|TRIGGER|DATABASE|SCHEMA|GRANT|REVOKE|COMMIT|ROLLBACK|SAVEPOINT|BEGIN|TRANSACTION|IF|ELSE|END|THEN|WHEN|CASE|LIMIT|OFFSET|FETCH|TOP|WITH|RECURSIVE|DECLARE|CURSOR|OPEN|CLOSE|FETCH|NEXT)\\b", tokenType: .keyword, options: .caseInsensitive),
            SyntaxRule(pattern: "\\b(INT|INTEGER|BIGINT|SMALLINT|TINYINT|FLOAT|DOUBLE|DECIMAL|NUMERIC|CHAR|VARCHAR|TEXT|BLOB|DATE|DATETIME|TIMESTAMP|BOOLEAN|SERIAL|UUID)\\b", tokenType: .type, options: .caseInsensitive),
            SyntaxRule(pattern: "\\b(COUNT|SUM|AVG|MIN|MAX|COALESCE|NULLIF|CAST|CONVERT|CONCAT|SUBSTRING|TRIM|UPPER|LOWER|LENGTH|REPLACE|ROUND|FLOOR|CEIL|ABS|NOW|CURRENT_DATE|CURRENT_TIMESTAMP)\\b", tokenType: .function, options: .caseInsensitive),
            SyntaxRule(pattern: "\\b(TRUE|FALSE|NULL)\\b", tokenType: .constant, options: .caseInsensitive),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "--.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "--",
        stringDelimiters: ["'"]
    )
    
    static let shellDefinition = SyntaxDefinition(
        language: .shell,
        rules: [
            SyntaxRule(pattern: "\\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|select|until|return|exit|break|continue|local|export|readonly|declare|typeset|unset|shift|source|alias|unalias|set|eval|exec|trap|wait|read|echo|printf|test|true|false)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\$\\{?\\w+\\}?", tokenType: .variable),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'[^']*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "^#!.*$", tokenType: .preprocessor, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let perlDefinition = SyntaxDefinition(
        language: .perl,
        rules: [
            SyntaxRule(pattern: "\\b(my|our|local|use|require|package|sub|if|elsif|else|unless|while|until|for|foreach|do|last|next|redo|return|die|warn|print|say|chomp|chop|push|pop|shift|unshift|split|join|sort|reverse|map|grep|defined|undef|exists|delete|keys|values|each|open|close|read|write|seek|tell|eof|binmode|tie|untie|bless|ref)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "[$@%]\\w+", tokenType: .variable),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "=pod",
        multiLineCommentEnd: "=cut",
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let luaDefinition = SyntaxDefinition(
        language: .lua,
        rules: [
            SyntaxRule(pattern: "\\b(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|nil)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "--.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "--[[",
        multiLineCommentEnd: "]]",
        singleLineComment: "--",
        stringDelimiters: ["\"", "'"]
    )
    
    static let rDefinition = SyntaxDefinition(
        language: .r,
        rules: [
            SyntaxRule(pattern: "\\b(if|else|repeat|while|function|for|in|next|break|return|switch|library|require|source|TRUE|FALSE|NULL|NA|NA_integer_|NA_real_|NA_complex_|NA_character_|Inf|NaN)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(TRUE|FALSE|NULL|NA|Inf|NaN|T|F)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let kotlinDefinition = SyntaxDefinition(
        language: .kotlin,
        rules: [
            SyntaxRule(pattern: "\\b(abstract|annotation|as|break|by|catch|class|companion|const|constructor|continue|crossinline|data|delegate|do|else|enum|external|false|final|finally|for|fun|get|if|import|in|infix|init|inline|inner|interface|internal|is|lateinit|noinline|null|object|open|operator|out|override|package|private|protected|public|reified|return|sealed|set|super|suspend|tailrec|this|throw|true|try|typealias|typeof|val|var|vararg|when|where|while)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|null)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?[fFdDlL]?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "'"]
    )
    
    static let scalaDefinition = SyntaxDefinition(
        language: .scala,
        rules: [
            SyntaxRule(pattern: "\\b(abstract|case|catch|class|def|do|else|extends|false|final|finally|for|forSome|if|implicit|import|lazy|match|new|null|object|override|package|private|protected|return|sealed|super|this|throw|trait|true|try|type|val|var|while|with|yield|given|using|enum|then|export)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|null)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?[fFdDlL]?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\""]
    )
    
    static let dartDefinition = SyntaxDefinition(
        language: .dart,
        rules: [
            SyntaxRule(pattern: "\\b(abstract|as|assert|async|await|break|case|catch|class|const|continue|covariant|default|deferred|do|dynamic|else|enum|export|extends|extension|external|factory|false|final|finally|for|Function|get|hide|if|implements|import|in|interface|is|late|library|mixin|new|null|on|operator|part|required|rethrow|return|set|show|static|super|switch|sync|this|throw|true|try|typedef|var|void|while|with|yield)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|null)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "//.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/",
        singleLineComment: "//",
        stringDelimiters: ["\"", "'"]
    )
    
    static let elixirDefinition = SyntaxDefinition(
        language: .elixir,
        rules: [
            SyntaxRule(pattern: "\\b(after|alias|and|case|catch|cond|def|defcallback|defdelegate|defexception|defimpl|defmacro|defmacrop|defmodule|defoverridable|defp|defprotocol|defstruct|do|else|end|false|fn|for|if|import|in|nil|not|or|quote|raise|receive|require|rescue|true|try|unless|unquote|unquote_splicing|use|when|with)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(true|false|nil)\\b", tokenType: .constant),
            SyntaxRule(pattern: ":\\w+", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
            SyntaxRule(pattern: "@\\w+", tokenType: .attribute),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let haskellDefinition = SyntaxDefinition(
        language: .haskell,
        rules: [
            SyntaxRule(pattern: "\\b(as|case|class|data|default|deriving|do|else|forall|foreign|hiding|if|import|in|infix|infixl|infixr|instance|let|module|newtype|of|qualified|then|type|where|family|pattern|role|mdo|rec|proc)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b(True|False|Nothing|Just|Left|Right|IO|Maybe|Either|String|Int|Integer|Float|Double|Bool|Char|Ord|Eq|Show|Read|Num|Monad|Functor|Applicative)\\b", tokenType: .type),
            SyntaxRule(pattern: "\\b(True|False|Nothing)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)'", tokenType: .string),
            SyntaxRule(pattern: "--.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: "{-",
        multiLineCommentEnd: "-}",
        singleLineComment: "--",
        stringDelimiters: ["\""]
    )
    
    static let tomlDefinition = SyntaxDefinition(
        language: .toml,
        rules: [
            SyntaxRule(pattern: "^\\s*\\[\\[?[\\w.-]+\\]\\]?", tokenType: .keyword, options: .anchorsMatchLines),
            SyntaxRule(pattern: "^\\s*[\\w.-]+\\s*=", tokenType: .variable, options: .anchorsMatchLines),
            SyntaxRule(pattern: "\\b(true|false)\\b", tokenType: .constant),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let iniDefinition = SyntaxDefinition(
        language: .ini,
        rules: [
            SyntaxRule(pattern: "^\\s*\\[[^\\]]+\\]", tokenType: .keyword, options: .anchorsMatchLines),
            SyntaxRule(pattern: "^\\s*[\\w.-]+\\s*=", tokenType: .variable, options: .anchorsMatchLines),
            SyntaxRule(pattern: "\\b(true|false|yes|no|on|off)\\b", tokenType: .constant, options: .caseInsensitive),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "[;#].*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: ";",
        stringDelimiters: ["\""]
    )
    
    static let dockerfileDefinition = SyntaxDefinition(
        language: .dockerfile,
        rules: [
            SyntaxRule(pattern: "^\\s*(FROM|RUN|CMD|LABEL|MAINTAINER|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\\b", tokenType: .keyword, options: [.anchorsMatchLines, .caseInsensitive]),
            SyntaxRule(pattern: "\\$\\{?\\w+\\}?", tokenType: .variable),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
    
    static let makefileDefinition = SyntaxDefinition(
        language: .makefile,
        rules: [
            SyntaxRule(pattern: "^[\\w.-]+\\s*:", tokenType: .keyword, options: .anchorsMatchLines),
            SyntaxRule(pattern: "\\$[({][\\w@<^?*%]+[)}]", tokenType: .variable),
            SyntaxRule(pattern: "\\b(ifeq|ifneq|ifdef|ifndef|else|endif|include|define|endef|override|export|unexport|vpath|.PHONY|.SUFFIXES|.DEFAULT|.PRECIOUS|.INTERMEDIATE|.SECONDARY|.SECONDEXPANSION|.DELETE_ON_ERROR|.IGNORE|.LOW_RESOLUTION_TIME|.SILENT|.EXPORT_ALL_VARIABLES|.NOTPARALLEL|.ONESHELL|.POSIX)\\b", tokenType: .keyword),
            SyntaxRule(pattern: "\\b\\d+(\\.\\d+)?\\b", tokenType: .number),
            SyntaxRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", tokenType: .string),
            SyntaxRule(pattern: "'(?:[^'\\\\]|\\\\.)*'", tokenType: .string),
            SyntaxRule(pattern: "#.*$", tokenType: .comment, options: .anchorsMatchLines),
        ],
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil,
        singleLineComment: "#",
        stringDelimiters: ["\"", "'"]
    )
}

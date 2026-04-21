import Foundation

/// Text encodings supported by WxMEditSwift.
///
/// Mirrors the multi-encoding capability of wxMEdit, which is one of its
/// signature features (it supports many legacy CJK and European code pages
/// in addition to Unicode encodings).
public enum TextEncoding: String, CaseIterable, Identifiable, Codable {
    // Unicode
    case utf8        = "UTF-8"
    case utf8BOM     = "UTF-8 (with BOM)"
    case utf16LE     = "UTF-16 LE"
    case utf16BE     = "UTF-16 BE"
    case utf32LE     = "UTF-32 LE"
    case utf32BE     = "UTF-32 BE"

    // Western
    case ascii       = "ASCII"
    case latin1      = "ISO-8859-1 (Latin-1)"
    case latin2      = "ISO-8859-2 (Latin-2)"
    case windows1252 = "Windows-1252"

    // CJK (commonly used by wxMEdit users)
    case shiftJIS    = "Shift-JIS"
    case eucJP       = "EUC-JP"
    case gb18030     = "GB18030"
    case big5        = "Big5"
    case eucKR       = "EUC-KR"

    // Cyrillic
    case windows1251 = "Windows-1251"
    case koi8r       = "KOI8-R"

    public var id: String { rawValue }

    /// Returns the Foundation `String.Encoding` value if available.
    /// Some encodings (UTF-8 with BOM) share an underlying Foundation encoding
    /// but differ in how the file bytes are read/written.
    public var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM:   return .utf8
        case .utf16LE:          return .utf16LittleEndian
        case .utf16BE:          return .utf16BigEndian
        case .utf32LE:          return .utf32LittleEndian
        case .utf32BE:          return .utf32BigEndian
        case .ascii:            return .ascii
        case .latin1:           return .isoLatin1
        case .latin2:           return .isoLatin2
        case .windows1252:      return .windowsCP1252
        case .shiftJIS:         return .shiftJIS
        case .eucJP:            return .japaneseEUC
        case .gb18030:          return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        case .big5:             return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        case .eucKR:            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        case .windows1251:      return .windowsCP1251
        case .koi8r:            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.KOI8_R.rawValue)))
        }
    }

    /// Byte-order-mark for this encoding, if any.
    public var bom: Data? {
        switch self {
        case .utf8BOM:  return Data([0xEF, 0xBB, 0xBF])
        case .utf16LE:  return Data([0xFF, 0xFE])
        case .utf16BE:  return Data([0xFE, 0xFF])
        case .utf32LE:  return Data([0xFF, 0xFE, 0x00, 0x00])
        case .utf32BE:  return Data([0x00, 0x00, 0xFE, 0xFF])
        default:        return nil
        }
    }

    /// Detects an encoding from a leading byte-order-mark, if present.
    public static func detectBOM(in data: Data) -> TextEncoding? {
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { return .utf32BE }
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) { return .utf32LE }
        if data.starts(with: [0xEF, 0xBB, 0xBF])       { return .utf8BOM }
        if data.starts(with: [0xFE, 0xFF])             { return .utf16BE }
        if data.starts(with: [0xFF, 0xFE])             { return .utf16LE }
        return nil
    }
}

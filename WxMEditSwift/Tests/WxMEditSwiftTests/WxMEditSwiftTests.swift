import XCTest
@testable import WxMEditSwift

final class WxMEditSwiftTests: XCTestCase {

    // MARK: - LineEnding

    func testLineEndingDetection() {
        XCTAssertEqual(LineEnding.detect(in: "a\nb\nc"),     .lf)
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb\r\n"),  .crlf)
        XCTAssertEqual(LineEnding.detect(in: "a\rb\rc"),     .cr)
        XCTAssertEqual(LineEnding.detect(in: "no newlines"), .lf)
    }

    func testLineEndingNormalize() {
        XCTAssertEqual(LineEnding.lf.normalize("a\r\nb\rc\n"),   "a\nb\nc\n")
        XCTAssertEqual(LineEnding.crlf.normalize("a\nb"),         "a\r\nb")
        XCTAssertEqual(LineEnding.cr.normalize("a\r\nb\nc"),      "a\rb\rc")
    }

    // MARK: - TextEncoding

    func testBOMDetection() {
        XCTAssertEqual(TextEncoding.detectBOM(in: Data([0xEF, 0xBB, 0xBF, 0x41])), .utf8BOM)
        XCTAssertEqual(TextEncoding.detectBOM(in: Data([0xFF, 0xFE, 0x41, 0x00])), .utf16LE)
        XCTAssertEqual(TextEncoding.detectBOM(in: Data([0xFE, 0xFF, 0x00, 0x41])), .utf16BE)
        XCTAssertNil(TextEncoding.detectBOM(in: Data([0x41, 0x42])))
    }

    // MARK: - HexService

    func testHexRenderBasic() {
        let data = Data("Hello".utf8)
        let rendered = HexService.render(data, bytesPerRow: 16)
        // Offset prefix, hex bytes for "Hello", and the ASCII pane is "Hello" + 11 spaces of padding.
        XCTAssertTrue(rendered.hasPrefix("00000000  48 65 6C 6C 6F"))
        XCTAssertTrue(rendered.hasSuffix("Hello           "))
    }

    func testHexRenderMultipleRows() {
        let data = Data(repeating: 0xAB, count: 33)
        let lines = HexService.render(data, bytesPerRow: 16).split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasPrefix("00000000"))
        XCTAssertTrue(lines[1].hasPrefix("00000010"))
        XCTAssertTrue(lines[2].hasPrefix("00000020"))
    }

    func testHexParseRoundtrip() {
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertEqual(HexService.parseHex("DEADBEEF"),     original)
        XCTAssertEqual(HexService.parseHex("de ad be ef"),  original)
        XCTAssertEqual(HexService.parseHex("DE\nAD\tBEEF"), original)
        XCTAssertNil(HexService.parseHex("ZZ"))
        XCTAssertNil(HexService.parseHex("ABC"))   // odd length
    }

    func testHexReplaceBytes() {
        var data = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        HexService.replaceBytes(in: &data, offset: 1, count: 2, with: Data([0xAA, 0xBB, 0xCC]))
        XCTAssertEqual(data, Data([0x00, 0xAA, 0xBB, 0xCC, 0x03, 0x04]))
    }

    // MARK: - ColumnEditService

    func testColumnExtract() {
        let text = "hello world\nfoo bar\nabcdefg"
        let rect = ColumnRect(startLine: 0, endLine: 2, startColumn: 2, endColumn: 5)
        XCTAssertEqual(ColumnEditService.extract(text, rect: rect), ["llo", "o b", "cde"])
    }

    func testColumnDelete() {
        let text = "hello\nworld"
        let rect = ColumnRect(startLine: 0, endLine: 1, startColumn: 1, endColumn: 4)
        XCTAssertEqual(ColumnEditService.delete(text, rect: rect), "ho\nwd")
    }

    func testColumnFill() {
        let text = "abcdef\nghijkl"
        let rect = ColumnRect(startLine: 0, endLine: 1, startColumn: 1, endColumn: 4)
        XCTAssertEqual(ColumnEditService.fill(text, rect: rect, with: "*"), "a***ef\ng***kl")
    }

    func testColumnInsertPadsShortLines() {
        let text = "abc\nx\nlonger line"
        let result = ColumnEditService.insert(text, value: "[]", at: 5, lines: 0...2)
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines[0], "abc  []")
        XCTAssertEqual(lines[1], "x    []")
        XCTAssertEqual(lines[2], "longe[]r line")
    }

    // MARK: - FindReplaceService

    func testFindLiteralCaseInsensitive() {
        let text = "Hello hello HELLO"
        let r = FindReplaceService.find("hello", in: text, options: .init(caseSensitive: false))
        XCTAssertEqual(r, NSRange(location: 0, length: 5))
    }

    func testFindCaseSensitive() {
        let text = "Hello hello HELLO"
        let r = FindReplaceService.find("hello", in: text, options: .init(caseSensitive: true))
        XCTAssertEqual(r, NSRange(location: 6, length: 5))
    }

    func testFindWrapAround() {
        let text = "abc abc"
        let r = FindReplaceService.find(
            "abc", in: text,
            options: .init(wrap: true),
            from: 5
        )
        XCTAssertEqual(r, NSRange(location: 0, length: 3))
    }

    func testReplaceAllLiteral() {
        let (out, n) = FindReplaceService.replaceAll("foo", with: "bar", in: "foo foo baz")
        XCTAssertEqual(out, "bar bar baz")
        XCTAssertEqual(n, 2)
    }

    func testReplaceAllRegex() {
        let (out, n) = FindReplaceService.replaceAll(
            "(\\w+)@(\\w+)", with: "$2/$1",
            in: "alice@one bob@two",
            options: .init(regex: true)
        )
        XCTAssertEqual(out, "one/alice two/bob")
        XCTAssertEqual(n, 2)
    }

    // MARK: - Document

    func testDocumentSetTextKeepsBytesInSync() {
        let doc = Document(encoding: .utf8)
        doc.setText("hi")
        XCTAssertEqual(doc.bytes, Data("hi".utf8))
        XCTAssertTrue(doc.isDirty)
    }

    func testDocumentSetTextWithBOMEncoding() {
        let doc = Document(encoding: .utf8BOM)
        doc.setText("hi")
        XCTAssertEqual(doc.bytes.prefix(3), Data([0xEF, 0xBB, 0xBF]))
        XCTAssertEqual(doc.bytes.dropFirst(3), Data("hi".utf8))
    }

    func testDocumentSetBytesDecodes() {
        let doc = Document(encoding: .utf8)
        doc.setBytes(Data("héllo".utf8))
        XCTAssertEqual(doc.text, "héllo")
    }
}

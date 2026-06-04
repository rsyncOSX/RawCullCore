import CoreGraphics
import Testing
@testable import RawCullCore

@Suite("FocusPointParser")
struct FocusPointParserTests {
    @Test("Parses normalized focus point from integer values")
    func parsesIntegerValues() throws {
        let point = try #require(FocusPointParser.normalizedPoint(from: "6000 4000 3000 1000"))

        #expect(point.x == 0.5)
        #expect(point.y == 0.25)
    }

    @Test("Parses decimal numeric input")
    func parsesDecimalValues() throws {
        let point = try #require(FocusPointParser.normalizedPoint(from: "6000.0 4000.0 1500.0 3000.0"))

        #expect(point.x == 0.25)
        #expect(point.y == 0.75)
    }

    @Test("Accepts flexible whitespace")
    func acceptsFlexibleWhitespace() throws {
        let point = try #require(FocusPointParser.normalizedPoint(from: "6000\t4000\n4500 2000"))

        #expect(point.x == 0.75)
        #expect(point.y == 0.5)
    }

    @Test(
        "Rejects malformed focus point strings",
        arguments: [
            "",
            "6000 4000 3000",
            "6000 4000 3000 1000 42",
            "6000 nope 3000 1000",
            "0 4000 3000 1000",
            "6000 0 3000 1000",
            "-6000 4000 3000 1000",
            "6000 -4000 3000 1000"
        ]
    )
    func rejectsMalformedStrings(input: String) {
        #expect(FocusPointParser.normalizedPoint(from: input) == nil)
    }
}

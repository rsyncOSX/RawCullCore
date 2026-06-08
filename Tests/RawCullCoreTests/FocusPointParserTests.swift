import CoreGraphics
@testable import RawCullCore
import Testing

@Suite("FocusPointParser")
struct FocusPointParserTests {
    @Test
    func `Parses normalized focus point from integer values`() throws {
        let point = try #require(FocusPointParser.normalizedPoint(from: "6000 4000 3000 1000"))

        #expect(point.x == 0.5)
        #expect(point.y == 0.25)
    }

    @Test
    func `Parses decimal numeric input`() throws {
        let point = try #require(FocusPointParser.normalizedPoint(from: "6000.0 4000.0 1500.0 3000.0"))

        #expect(point.x == 0.25)
        #expect(point.y == 0.75)
    }

    @Test
    func `Accepts flexible whitespace`() throws {
        let point = try #require(FocusPointParser.normalizedPoint(from: "6000\t4000\n4500 2000"))

        #expect(point.x == 0.75)
        #expect(point.y == 0.5)
    }

    @Test(
        arguments: [
            "",
            "6000 4000 3000",
            "6000 4000 3000 1000 42",
            "6000 nope 3000 1000",
            "0 4000 3000 1000",
            "6000 0 3000 1000",
            "-6000 4000 3000 1000",
            "6000 -4000 3000 1000"
        ],
    )
    func `Rejects malformed focus point strings`(input: String) {
        #expect(FocusPointParser.normalizedPoint(from: input) == nil)
    }
}

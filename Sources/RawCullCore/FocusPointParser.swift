import CoreGraphics
import Foundation

public nonisolated enum FocusPointParser {
    /// Parses a MakerNote focus-location string ("width height x y") into a
    /// normalized point with origin at the top-left.
    public nonisolated static func normalizedPoint(from string: String) -> CGPoint? {
        let values = string
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .compactMap(Double.init)

        guard values.count == 4,
              values[0] > 0,
              values[1] > 0
        else { return nil }

        return CGPoint(x: values[2] / values[0], y: values[3] / values[1])
    }
}

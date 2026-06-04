# RawCullCore

RawCullCore is a Swift package for the pure, testable culling logic used by RawCullVerify. It owns package-safe metadata models, focus-point normalization, burst grouping and ranking, saliency summary values, and lightweight image statistics.

The package is intentionally independent of RawCullVerify view models, SwiftUI views, persistence, cache actors, rsync integration, RAW parser internals, and Metal/CoreImage/Vision scoring pipelines. It is designed to sit beside `RawParserKit`: `RawParserKit` understands RAW files and embedded previews, while RawCullCore understands culling-domain values and decisions.

## Requirements

- Swift 6
- macOS 26 or newer
- Apple platforms with Foundation and CoreGraphics

## Package Shape

RawCullCore uses Swift 6.2 package settings aligned with `RawParserKit`:

- `.defaultIsolation(MainActor.self)`
- `InferIsolatedConformances`
- `NonisolatedNonsendingByDefault`

The public value types and pure engines are explicitly `nonisolated` so they can be used safely from background scoring, grouping, and test code without inheriting app UI isolation.

## What The Package Provides

- `ExifMetadata`: a Codable, Hashable, Sendable value type for scanned camera metadata.
- `RawCullFileItem`: a package-safe file model with identity, URL, size, modification date, EXIF metadata, and normalized AF focus point.
- `RawCullSourceCatalog`: a package-safe catalog value.
- `FocusPointParser`: converts MakerNote focus strings like `"width height x y"` into normalized `CGPoint` values.
- `SaliencyInfo`: a small Codable summary of subject classification and confidence, without depending on Vision.
- `BurstGroupingEngine`: groups sequential files into bursts using visual distance, capture time, camera/lens metadata, focal length, and exposure stability.
- `BurstRankingEngine`: ranks burst candidates using sharpness scores, AF evidence, saliency labels, and metadata stability.
- `HistogramCalculator`: builds normalized 256-bin luminance histograms from 8-bit RGB/RGBA `CGImage` data.

## Deliberately Out Of Scope

RawCullCore does not include:

- RAW binary parsing, MakerNote traversal, embedded JPEG extraction, or thumbnail extraction. Those belong in `RawParserKit`.
- SwiftUI views, `@Observable` view models, app scenes, or presentation copy.
- Disk cache, memory cache, security-scoped URL lifecycle, settings persistence, or saved-file JSON storage.
- Vision feature-print indexing, Vision saliency detection, Metal kernels, CoreImage scoring, or focus-mask rendering.
- Rsync copy integration.

Those boundaries keep the package fast to build, easy to test, and reusable without dragging in app state or heavy image-processing dependencies.

## Usage

### Metadata Models

```swift
import RawCullCore

let metadata = ExifMetadata(
    shutterSpeed: "1/1000",
    focalLength: "600.0mm",
    aperture: "ƒ/5.6",
    apertureValue: 5.6,
    iso: "ISO 800",
    isoValue: 800,
    camera: "ILCE-1",
    lensModel: "FE 600mm F4 GM OSS",
    rawFileType: "Lossless Compressed",
    rawSizeClass: "L",
    pixelWidth: 8640,
    pixelHeight: 5760
)

let file = RawCullFileItem(
    url: URL(fileURLWithPath: "/photos/frame.ARW"),
    name: "frame.ARW",
    size: 53_755_904,
    dateModified: Date(),
    exifData: metadata,
    afFocusNormalized: nil
)
```

`RawCullFileItem` equality and hashing are identity-based, matching RawCullVerify's existing `FileItem` behavior.

### Focus Point Normalization

```swift
let point = FocusPointParser.normalizedPoint(from: "6000 4000 3000 1000")
// CGPoint(x: 0.5, y: 0.25)
```

Invalid strings, missing values, non-numeric values, and non-positive image dimensions return `nil`.

### Burst Grouping

```swift
let previous = files[0]
let current = files[1]

let distances = [
    BurstPairKey.cacheKey(previousID: previous.id, currentID: current.id): Float(0.12)
]

let output = BurstGroupingEngine.group(
    files: files,
    adjacentDistances: distances,
    config: BurstGroupingConfig(visualDistanceThreshold: 0.25)
)

print(output.groups)
print(output.boundaryEvidence)
```

Grouping expects files in shot order. It starts a new group when similarity evidence is missing, visual distance crosses the configured threshold, capture time exceeds the maximum gap, camera changes, focal length changes beyond the configured delta, or exposure changes.

### Burst Ranking

```swift
let filesByID = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
let scores: [UUID: Float] = [
    files[0].id: 0.52,
    files[1].id: 0.94,
    files[2].id: 0.71
]
let saliency: [UUID: SaliencyInfo] = [
    files[1].id: SaliencyInfo(subjectLabel: "bird", subjectConfidence: 0.93)
]

let results = BurstRankingEngine.rank(
    groups: output.groups,
    filesByID: filesByID,
    scores: scores,
    maxScore: 1.0,
    saliencyInfo: saliency,
    boundaryEvidence: output.boundaryEvidence
)

let recommendedID = results.first?.recommendedFileID
```

Ranking combines normalized sharpness, burst-relative sharpness, AF-point availability, saliency subject consistency, and metadata stability. High-confidence results are marked safe for one-click culling only when the scoring gap and metadata conditions are strong enough.

### Histogram Calculation

```swift
let histogram = HistogramCalculator.normalizedLuminanceHistogram(from: cgImage)

if histogram.count == HistogramCalculator.binCount {
    print("Peak:", histogram.max() ?? 0)
}
```

The histogram uses Rec. 601 luminance weighting:

```text
Y = 0.299R + 0.587G + 0.114B
```

Input must be an 8-bit RGB/RGBA-style `CGImage` with at least three bytes per pixel. Unsupported images return a zero-filled 256-bin histogram.

## Concurrency Notes

RawCullCore's public models and engines are pure value-oriented APIs. They do not perform file I/O, access app singletons, mutate shared state, or require actor hops. The package uses explicit `nonisolated` declarations to avoid accidental `MainActor` coupling under the project-wide default isolation setting.

Callers are responsible for doing expensive upstream work, such as RAW scanning, Vision embedding, saliency detection, and sharpness scoring, on the appropriate actor or task. RawCullCore consumes the resulting values.

## Development

Build the package:

```bash
swift build
```

Run tests:

```bash
swift test
```

Run tests with code coverage:

```bash
swift test --enable-code-coverage
```

## Test Strategy

The test suite uses Swift Testing and synthetic values. It does not require real photo catalogs, RAW files, Vision models, cache directories, settings files, or app state.

Current coverage includes:

- Codable, Hashable, and identity behavior for core models
- Focus-point parsing for valid, malformed, decimal, and whitespace-varied inputs
- Burst grouping for empty inputs, stable groups, missing similarity evidence, capture gaps, metadata changes, focal length changes, and exposure changes
- Burst ranking for relative sharpness normalization, missing scores, review-state propagation, high-confidence winners, and one-click culling eligibility
- Histogram calculation for RGB/RGBA luminance bins, normalization by maximum bin count, and unsupported image handling


import Foundation

public nonisolated struct ExifMetadata: Codable, Hashable, Sendable {
    public let shutterSpeed: String?
    public let focalLength: String?
    public let aperture: String?
    public let apertureValue: Double?
    public let iso: String?
    public let isoValue: Int?
    public let camera: String?
    public let lensModel: String?
    public let rawFileType: String?
    public let rawSizeClass: String?
    public let pixelWidth: Int?
    public let pixelHeight: Int?

    public nonisolated init(
        shutterSpeed: String?,
        focalLength: String?,
        aperture: String?,
        apertureValue: Double?,
        iso: String?,
        isoValue: Int?,
        camera: String?,
        lensModel: String?,
        rawFileType: String?,
        rawSizeClass: String?,
        pixelWidth: Int?,
        pixelHeight: Int?,
    ) {
        self.shutterSpeed = shutterSpeed
        self.focalLength = focalLength
        self.aperture = aperture
        self.apertureValue = apertureValue
        self.iso = iso
        self.isoValue = isoValue
        self.camera = camera
        self.lensModel = lensModel
        self.rawFileType = rawFileType
        self.rawSizeClass = rawSizeClass
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

import Foundation

public nonisolated struct BurstGroupingOutput: Equatable, Sendable {
    public let groups: [BurstGroup]
    public let boundaryEvidence: [BurstBoundaryEvidence]

    public nonisolated init(groups: [BurstGroup], boundaryEvidence: [BurstBoundaryEvidence]) {
        self.groups = groups
        self.boundaryEvidence = boundaryEvidence
    }
}

public nonisolated enum BurstGroupingEngine {
    public nonisolated static func group(
        files: [RawCullFileItem],
        adjacentDistances: [String: Float],
        config: BurstGroupingConfig,
    ) -> BurstGroupingOutput {
        guard !files.isEmpty else {
            return BurstGroupingOutput(groups: [], boundaryEvidence: [])
        }

        var rawGroups: [[UUID]] = [[files[0].id]]
        var evidence: [BurstBoundaryEvidence] = []

        for index in files.indices.dropFirst() {
            let previous = files[index - 1]
            let current = files[index]
            let key = BurstPairKey.cacheKey(previousID: previous.id, currentID: current.id)
            let visualDistance = adjacentDistances[key]
            let timeGap = current.effectiveCaptureDate.timeIntervalSince(previous.effectiveCaptureDate)
            let captureTimeUsedFallback = previous.usesFileModificationDateForCaptureTime
                || current.usesFileModificationDateForCaptureTime
            let focalDelta = focalLengthDelta(previous: previous, current: current)
            let cameraChanged = normalized(previous.exifData?.camera) != normalized(current.exifData?.camera)
            let lensChanged = normalized(previous.exifData?.lensModel) != normalized(current.exifData?.lensModel)
            let exposureComparison = exposureComparison(
                previous: previous,
                current: current,
                config: config,
            )

            var startsNewGroup = false
            var reasons: [String] = []

            if let visualDistance {
                if visualDistance >= config.visualDistanceThreshold {
                    startsNewGroup = true
                    reasons.append("Visual distance changed")
                }
            } else {
                startsNewGroup = true
                reasons.append("Similarity evidence missing")
            }

            let maximumTimeGap = captureTimeUsedFallback
                ? config.maxFallbackTimeGapSeconds
                : config.maxTimeGapSeconds
            if abs(timeGap) > maximumTimeGap {
                startsNewGroup = true
                reasons.append("Capture gap")
            }

            if config.requireSameCamera, cameraChanged {
                startsNewGroup = true
                reasons.append("Camera changed")
            }

            if config.requireSimilarFocalLength,
               let focalDelta,
               focalDelta > config.maxFocalLengthDeltaMM {
                startsNewGroup = true
                reasons.append("Focal length changed")
            }

            if exposureComparison.materiallyChanged {
                startsNewGroup = true
                reasons.append("Exposure changed")
            }

            evidence.append(BurstBoundaryEvidence(
                previousID: previous.id,
                currentID: current.id,
                visualDistance: visualDistance,
                timeGapSeconds: abs(timeGap),
                captureTimeUsedFallback: captureTimeUsedFallback,
                focalLengthDelta: focalDelta,
                exposureAdjustmentEV: exposureComparison.maximumAdjustmentEV,
                exposureChanged: exposureComparison.materiallyChanged,
                cameraChanged: cameraChanged,
                lensChanged: lensChanged,
                startsNewGroup: startsNewGroup,
                reasons: reasons,
            ))

            if startsNewGroup {
                rawGroups.append([current.id])
            } else {
                rawGroups[rawGroups.index(before: rawGroups.endIndex)].append(current.id)
            }
        }

        let groups = rawGroups.enumerated().map { BurstGroup(id: $0.offset, fileIDs: $0.element) }
        return BurstGroupingOutput(groups: groups, boundaryEvidence: evidence)
    }

    private nonisolated struct ExposureComparison {
        let maximumAdjustmentEV: Double?
        let materiallyChanged: Bool
    }

    private nonisolated static func exposureComparison(
        previous: RawCullFileItem,
        current: RawCullFileItem,
        config: BurstGroupingConfig,
    ) -> ExposureComparison {
        let previousExif = previous.exifData
        let currentExif = current.exifData
        let shutterDelta = stopDelta(
            exposureTimeSeconds(previousExif),
            exposureTimeSeconds(currentExif),
        )
        let apertureDelta = stopDelta(
            apertureValue(previousExif),
            apertureValue(currentExif),
            multiplier: 2,
        )
        let isoDelta = stopDelta(
            isoValue(previousExif),
            isoValue(currentExif),
        )
        let compensationDelta = linearDelta(
            previousExif?.exposureCompensationEV,
            currentExif?.exposureCompensationEV,
        )
        let deltas = [shutterDelta, apertureDelta, isoDelta, compensationDelta].compactMap { $0 }
        let maximumAdjustmentEV = deltas.max()

        let materiallyChanged = shutterDelta.map { $0 > config.maxShutterSpeedDeltaEV } == true
            || apertureDelta.map { $0 > config.maxApertureDeltaEV } == true
            || isoDelta.map { $0 > config.maxISODeltaEV } == true
            || compensationDelta.map { $0 > config.maxExposureCompensationDeltaEV } == true
            || unquantifiedExposureChanged(
                previous: previousExif,
                current: currentExif,
                shutterWasCompared: shutterDelta != nil,
                apertureWasCompared: apertureDelta != nil,
                isoWasCompared: isoDelta != nil,
            )

        return ExposureComparison(
            maximumAdjustmentEV: maximumAdjustmentEV,
            materiallyChanged: materiallyChanged,
        )
    }

    private nonisolated static func focalLengthDelta(previous: RawCullFileItem, current: RawCullFileItem) -> Double? {
        guard let previousFocal = focalLengthMM(previous.exifData),
              let currentFocal = focalLengthMM(current.exifData)
        else { return nil }
        return abs(previousFocal - currentFocal)
    }

    private nonisolated static func focalLengthMM(_ exif: ExifMetadata?) -> Double? {
        validPositive(exif?.focalLengthMM) ?? firstNumber(in: exif?.focalLength).flatMap(validPositive)
    }

    private nonisolated static func exposureTimeSeconds(_ exif: ExifMetadata?) -> Double? {
        if let value = validPositive(exif?.exposureTimeSeconds) { return value }
        guard let shutter = exif?.shutterSpeed else { return nil }
        let parts = shutter.split(separator: "/", maxSplits: 1).map(String.init)
        if parts.count == 2,
           let numerator = firstNumber(in: parts[0]).flatMap(validPositive),
           let denominator = firstNumber(in: parts[1]).flatMap(validPositive) {
            return numerator / denominator
        }
        return firstNumber(in: shutter).flatMap(validPositive)
    }

    private nonisolated static func apertureValue(_ exif: ExifMetadata?) -> Double? {
        validPositive(exif?.apertureValue) ?? firstNumber(in: exif?.aperture).flatMap(validPositive)
    }

    private nonisolated static func isoValue(_ exif: ExifMetadata?) -> Double? {
        if let iso = exif?.isoValue { return validPositive(Double(iso)) }
        return firstNumber(in: exif?.iso).flatMap(validPositive)
    }

    private nonisolated static func stopDelta(
        _ lhs: Double?,
        _ rhs: Double?,
        multiplier: Double = 1,
    ) -> Double? {
        guard let lhs = validPositive(lhs), let rhs = validPositive(rhs) else { return nil }
        return abs(log2(rhs / lhs)) * multiplier
    }

    private nonisolated static func linearDelta(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, lhs.isFinite, let rhs, rhs.isFinite else { return nil }
        return abs(rhs - lhs)
    }

    private nonisolated static func validPositive(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    private nonisolated static func firstNumber(in value: String?) -> Double? {
        guard let value,
              let start = value.firstIndex(where: { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" })
        else { return nil }
        let number = value[start...].prefix {
            $0.isNumber || $0 == "." || $0 == "-" || $0 == "+"
        }
        return Double(number)
    }

    private nonisolated static func unquantifiedExposureChanged(
        previous: ExifMetadata?,
        current: ExifMetadata?,
        shutterWasCompared: Bool,
        apertureWasCompared: Bool,
        isoWasCompared: Bool,
    ) -> Bool {
        (!shutterWasCompared && bothPresentValuesDiffer(previous?.shutterSpeed, current?.shutterSpeed))
            || (!apertureWasCompared && bothPresentValuesDiffer(previous?.aperture, current?.aperture))
            || (!isoWasCompared && bothPresentValuesDiffer(previous?.iso, current?.iso))
    }

    private nonisolated static func bothPresentValuesDiffer(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = normalized(lhs), let rhs = normalized(rhs) else { return false }
        return lhs != rhs
    }

    private nonisolated static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

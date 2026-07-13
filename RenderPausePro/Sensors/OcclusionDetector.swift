import CoreGraphics
import Foundation

/// Geometry-based full-occlusion approximation for watched apps.
/// Uses axis-aligned rectangles from CGWindow list (front-to-back order).
/// Biases toward "still visible" so we do not hide apps the user can still see.
enum OcclusionDetector {
    /// Residual visible fraction above this → partially visible (protect).
    static let residualVisibleThreshold: CGFloat = 0.005
    /// Absolute residual area (points²) above this also counts as visible,
    /// so a thin peek strip still protects even on large windows.
    static let residualVisibleMinArea: CGFloat = 2_500

    /// True when any significant window still has residual unoccluded area.
    /// No significant on-screen windows → not partially visible (eligible as fully occluded).
    static func isPartiallyVisible(
        bundleID: String,
        windows: [SplitViewDetector.WindowRect]
    ) -> Bool {
        let targets = significantContentWindows(in: windows, bundleID: bundleID)
        guard !targets.isEmpty else { return false }

        // CGWindowList is front-to-back. Only *normal* windows (layer 0) may cover content.
        // Menu bar, Dock (layer 20+), overlays must NOT count — otherwise every app looks
        // fully occluded by the Dock's full-screen hit region.
        for (index, window) in windows.enumerated() {
            guard window.bundleID == bundleID, isContentCoverWindow(window) else { continue }
            guard window.bounds.width >= 200, window.bounds.height >= 200 else { continue }

            let covers = windows.prefix(index)
                .filter { isContentCoverWindow($0) }
                .filter { $0.bundleID != bundleID }
                .map(\.bounds)

            if hasSignificantResidual(of: window.bounds, coveredBy: covers) {
                return true
            }
        }
        return false
    }

    /// Whether residual unoccluded region is meaningful enough to protect.
    static func hasSignificantResidual(of rect: CGRect, coveredBy covers: [CGRect]) -> Bool {
        let fraction = residualVisibleFraction(of: rect, coveredBy: covers)
        if fraction > residualVisibleThreshold { return true }
        let area = rect.width * rect.height
        let residualArea = fraction * area
        return residualArea >= residualVisibleMinArea
    }

    /// Fraction of `rect` still visible after subtracting covering rects.
    static func residualVisibleFraction(of rect: CGRect, coveredBy covers: [CGRect]) -> CGFloat {
        let area = rect.width * rect.height
        guard area > 0 else { return 0 }

        var fragments: [CGRect] = [rect]
        for cover in covers {
            var next: [CGRect] = []
            next.reserveCapacity(fragments.count * 2)
            for fragment in fragments {
                next.append(contentsOf: subtract(fragment, minus: cover))
            }
            fragments = next
            if fragments.isEmpty { return 0 }
        }

        let residualArea = fragments.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
        return min(1, residualArea / area)
    }

    /// Returns non-overlapping rects = `rect` minus `cut` intersection.
    static func subtract(_ rect: CGRect, minus cut: CGRect) -> [CGRect] {
        let inter = rect.intersection(cut)
        guard !inter.isNull, inter.width > 0.5, inter.height > 0.5 else {
            return [rect]
        }

        var parts: [CGRect] = []
        // CGWindow coords: origin top-left, y grows downward.
        let topHeight = inter.minY - rect.minY
        if topHeight > 0.5 {
            parts.append(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: topHeight))
        }
        let bottomY = inter.maxY
        let bottomHeight = rect.maxY - inter.maxY
        if bottomHeight > 0.5 {
            parts.append(CGRect(x: rect.minX, y: bottomY, width: rect.width, height: bottomHeight))
        }
        let midHeight = inter.height
        if midHeight > 0.5 {
            let leftWidth = inter.minX - rect.minX
            if leftWidth > 0.5 {
                parts.append(CGRect(x: rect.minX, y: inter.minY, width: leftWidth, height: midHeight))
            }
            let rightX = inter.maxX
            let rightWidth = rect.maxX - inter.maxX
            if rightWidth > 0.5 {
                parts.append(CGRect(x: rightX, y: inter.minY, width: rightWidth, height: midHeight))
            }
        }
        return parts
    }

    // MARK: - Filters

    /// Standard app content windows that we care about for visibility.
    static func significantContentWindows(
        in windows: [SplitViewDetector.WindowRect],
        bundleID: String
    ) -> [SplitViewDetector.WindowRect] {
        windows
            .filter { $0.bundleID == bundleID }
            .filter { isContentCoverWindow($0) }
            .filter { $0.bounds.width >= 200 && $0.bounds.height >= 200 }
            .sorted { ($0.bounds.width * $0.bounds.height) > ($1.bounds.width * $1.bounds.height) }
    }

    /// Layer 0 normal windows only (excludes Dock / menu extras / HUD).
    static func isContentCoverWindow(_ window: SplitViewDetector.WindowRect) -> Bool {
        window.layer <= 0
            && window.bounds.width >= 80
            && window.bounds.height >= 80
    }
}

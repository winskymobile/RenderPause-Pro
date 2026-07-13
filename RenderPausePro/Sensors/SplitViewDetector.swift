import AppKit
import CoreGraphics
import Foundation

/// Heuristic detector for macOS Split View / side-by-side tiled windows.
/// Public APIs do not expose "this app is in Split View", so we infer from
/// on-screen window geometry. CGWindow bounds use global top-left coordinates;
/// comparisons stay within that space and only use screen *sizes* from NSScreen.
enum SplitViewDetector {
    struct WindowRect: Equatable {
        var bundleID: String
        var bounds: CGRect
        var layer: Int32
    }

    static func isSplitPartner(
        candidateBundleID: String,
        frontmostBundleID: String?,
        windows: [WindowRect]? = nil
    ) -> Bool {
        guard let frontmostBundleID,
              frontmostBundleID != candidateBundleID else { return false }

        let all = windows ?? listOnScreenWindows()
        let frontWindows = significantWindows(in: all, bundleID: frontmostBundleID)
        let candidateWindows = significantWindows(in: all, bundleID: candidateBundleID)
        guard let f = frontWindows.first, let c = candidateWindows.first else { return false }
        return looksLikeSplitPair(f.bounds, c.bounds)
    }

    static func splitPartnerBundleIDs(
        frontmostBundleID: String?,
        among candidates: Set<String>,
        windows: [WindowRect]? = nil
    ) -> Set<String> {
        guard let frontmostBundleID else { return [] }
        let all = windows ?? listOnScreenWindows()
        var result: Set<String> = []
        for id in candidates where id != frontmostBundleID {
            if isSplitPartner(candidateBundleID: id, frontmostBundleID: frontmostBundleID, windows: all) {
                result.insert(id)
            }
        }
        return result
    }

    /// Pure geometry check (used by unit tests).
    static func looksLikeSplitPair(_ a: CGRect, _ b: CGRect) -> Bool {
        looksLikeSplitPair(a, b, screenWidth: maxScreenWidth(), screenHeight: maxScreenHeight())
    }

    static func looksLikeSplitPair(
        _ a: CGRect,
        _ b: CGRect,
        screenWidth: CGFloat,
        screenHeight: CGFloat
    ) -> Bool {
        let screenW = screenWidth
        let screenH = screenHeight

        // Tall tiles (Split View fills most of the vertical space).
        let minHeight = screenH * 0.55
        guard a.height >= minHeight, b.height >= minHeight else { return false }

        // Each side takes a meaningful width.
        let minWidth = screenW * 0.18
        guard a.width >= minWidth, b.width >= minWidth else { return false }

        // Same row: vertical centers close.
        guard abs(a.midY - b.midY) <= screenH * 0.20 else { return false }

        // Side-by-side: horizontal centers apart.
        guard abs(a.midX - b.midX) >= screenW * 0.15 else { return false }

        // Not heavily overlapping (one covering the other).
        let inter = a.intersection(b)
        if !inter.isNull, inter.width > 1, inter.height > 1 {
            let interArea = inter.width * inter.height
            let minArea = min(a.width * a.height, b.width * b.height)
            if minArea > 0, interArea / minArea > 0.45 {
                return false
            }
        }

        // Combined span covers most of a display width.
        let span = max(a.maxX, b.maxX) - min(a.minX, b.minX)
        return span >= screenW * 0.55
    }

    static func significantWindows(in windows: [WindowRect], bundleID: String) -> [WindowRect] {
        windows
            .filter { $0.bundleID == bundleID }
            .filter { $0.layer <= 0 }
            .filter { $0.bounds.width >= 200 && $0.bounds.height >= 200 }
            .sorted { ($0.bounds.width * $0.bounds.height) > ($1.bounds.width * $1.bounds.height) }
    }

    static func listOnScreenWindows() -> [WindowRect] {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var pidToBundle: [Int32: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier {
                pidToBundle[app.processIdentifier] = id
            }
        }

        return info.compactMap { dict -> WindowRect? in
            guard let pid = (dict[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let bundleID = pidToBundle[pid],
                  let b = dict[kCGWindowBounds as String] as? NSDictionary,
                  let x = cgf(b["X"]),
                  let y = cgf(b["Y"]),
                  let w = cgf(b["Width"]),
                  let h = cgf(b["Height"]) else {
                return nil
            }
            let layer = (dict[kCGWindowLayer as String] as? NSNumber)?.int32Value ?? 0
            return WindowRect(
                bundleID: bundleID,
                bounds: CGRect(x: x, y: y, width: w, height: h),
                layer: layer
            )
        }
    }

    private static func cgf(_ any: Any?) -> CGFloat? {
        if let n = any as? NSNumber { return CGFloat(truncating: n) }
        return nil
    }

    private static func maxScreenWidth() -> CGFloat {
        NSScreen.screens.map(\.frame.width).max() ?? 1440
    }

    private static func maxScreenHeight() -> CGFloat {
        NSScreen.screens.map(\.frame.height).max() ?? 900
    }
}

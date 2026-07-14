import Foundation

/// Runtime feature gates. Prefer flags over deleting product surfaces.
enum FeatureFlags {
    /// When false: prefs hide「隐藏模式」UI, runtime always uses `.hide`, menu bar drops AX items.
    /// Minimize code paths remain compiled for tests / future re-enable.
    static let allowMinimizeMode = false
}

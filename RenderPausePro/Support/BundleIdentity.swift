import Foundation

enum BundleIdentity {
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.renderpause.pro"
    }

    static var appName: String { "RenderPause Pro" }
}

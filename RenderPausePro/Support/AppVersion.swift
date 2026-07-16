import Foundation

/// Marketing / GitHub tag version helpers (major.minor.patch).
enum AppVersion {
    struct Triple: Comparable, Equatable, Sendable {
        let major: Int
        let minor: Int
        let patch: Int

        static func < (lhs: Triple, rhs: Triple) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }

        var display: String { "\(major).\(minor).\(patch)" }
        var displayWithV: String { "v\(display)" }
    }

    /// Parse `1.2.3`, `v1.2.3`, ignore pre-release suffix after `-`.
    static func parse(_ raw: String) -> Triple? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s = String(s.dropFirst())
        }
        if let dash = s.firstIndex(of: "-") {
            s = String(s[..<dash])
        }
        if let plus = s.firstIndex(of: "+") {
            s = String(s[..<plus])
        }
        let parts = s.split(separator: ".").map(String.init)
        guard parts.count >= 2, parts.count <= 3 else { return nil }
        guard let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        let patch = parts.count == 3 ? (Int(parts[2]) ?? 0) : 0
        return Triple(major: major, minor: minor, patch: patch)
    }

    static func localMarketing() -> Triple {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return parse(short ?? "0.0.0") ?? Triple(major: 0, minor: 0, patch: 0)
    }

    /// First 64-char hex token from a `.sha256` file body.
    static func parseSHA256Checksum(_ text: String) -> String? {
        let pattern = #"\b[a-fA-F0-9]{64}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange]).lowercased()
    }
}

import AppKit
import CryptoKit
import Foundation

/// GitHub Releases update flow for public repo zip + .sha256 assets.
@MainActor
final class UpdateService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateRelease)
        case downloading
        case ready(localURL: URL, release: UpdateRelease)
        case failed(String)
    }

    struct UpdateRelease: Equatable {
        let version: AppVersion.Triple
        let tagName: String
        let zipURL: URL
        let shaURL: URL?
        let htmlURL: URL?
    }

    enum CheckReason: Sendable {
        case launch
        case manual
        case preDownload
    }

    @Published private(set) var phase: Phase = .idle

    private let owner = "winskymobile"
    private let repo = "RenderPause-Pro"
    private let session: URLSession
    private var checkTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
    }

    var statusText: String {
        switch phase {
        case .idle:
            return ""
        case .checking:
            return "检查中…"
        case .upToDate:
            return "已是最新版本"
        case .available(let r):
            return "发现 \(r.version.displayWithV)"
        case .downloading:
            return "下载中…"
        case .ready(_, let r):
            return "已下载 \(r.version.displayWithV)"
        case .failed(let message):
            return message
        }
    }

    var buttonTitle: String {
        switch phase {
        case .available:
            return "下载更新"
        case .ready:
            return "在访达中显示"
        case .downloading:
            return "下载中…"
        case .checking:
            return "检查中…"
        case .idle, .upToDate, .failed:
            return "检查更新"
        }
    }

    var isButtonEnabled: Bool {
        switch phase {
        case .checking, .downloading:
            return false
        default:
            return true
        }
    }

    func primaryAction() {
        switch phase {
        case .available:
            startDownload()
        case .ready(let url, _):
            revealInFinder(url)
        case .idle, .upToDate, .failed:
            check(reason: .manual)
        case .checking, .downloading:
            break
        }
    }

    func check(reason: CheckReason) {
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            await self?.performCheck(reason: reason)
        }
    }

    func startDownload() {
        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            await self?.performDownload()
        }
    }

    func revealInFinder(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            phase = .failed("文件不存在，请重新下载")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Check

    private func performCheck(reason: CheckReason) async {
        if reason != .preDownload {
            phase = .checking
        }
        do {
            let release = try await fetchLatestRelease()
            if Task.isCancelled { return }
            let local = AppVersion.localMarketing()
            if release.version > local {
                phase = .available(release)
            } else {
                phase = .upToDate
            }
        } catch {
            if Task.isCancelled { return }
            if reason == .launch {
                phase = .idle
            } else {
                phase = .failed(shortError(error))
            }
        }
    }

    // MARK: - Download

    private func performDownload() async {
        phase = .checking
        let release: UpdateRelease
        do {
            let latest = try await fetchLatestRelease()
            if Task.isCancelled { return }
            let local = AppVersion.localMarketing()
            guard latest.version > local else {
                phase = .upToDate
                return
            }
            release = latest
            phase = .available(release)
        } catch {
            if Task.isCancelled { return }
            phase = .failed(shortError(error))
            return
        }

        phase = .downloading
        do {
            let fileName = preferredZipName(for: release.version)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dest = downloads.appendingPathComponent(fileName)

            // Reuse existing valid file.
            if FileManager.default.fileExists(atPath: dest.path),
               let expected = try await loadExpectedSHA(for: release),
               let existing = try? Data(contentsOf: dest),
               sha256Hex(existing) == expected {
                phase = .ready(localURL: dest, release: release)
                return
            }

            let tmp = dest.appendingPathExtension("download")
            try? FileManager.default.removeItem(at: tmp)

            let (tmpURL, response) = try await session.download(from: release.zipURL)
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: tmpURL)
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: tmpURL)
                throw UpdateError.httpStatus(http.statusCode)
            }

            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpURL, to: dest)

            let data = try Data(contentsOf: dest)
            guard let expected = try await loadExpectedSHA(for: release) else {
                try? FileManager.default.removeItem(at: dest)
                throw UpdateError.missingChecksum
            }
            let actual = sha256Hex(data)
            guard actual == expected else {
                try? FileManager.default.removeItem(at: dest)
                throw UpdateError.checksumMismatch
            }
            phase = .ready(localURL: dest, release: release)
        } catch {
            if Task.isCancelled { return }
            phase = .failed(shortError(error))
        }
    }

    // MARK: - GitHub

    private func fetchLatestRelease() async throws -> UpdateRelease {
        let api = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GitHubReleaseDTO.self, from: data)
        if decoded.draft == true || decoded.prerelease == true {
            // latest endpoint usually skips these; still guard
        }
        guard let triple = AppVersion.parse(decoded.tagName) else {
            throw UpdateError.badVersion(decoded.tagName)
        }

        let assets = decoded.assets ?? []
        guard let zipAsset = pickZipAsset(from: assets, version: triple) else {
            throw UpdateError.missingZipAsset
        }
        guard let zipURL = URL(string: zipAsset.browserDownloadURL) else {
            throw UpdateError.missingZipAsset
        }
        let shaAsset = pickSHAAsset(from: assets, zipName: zipAsset.name)
        let shaURL = shaAsset.flatMap { URL(string: $0.browserDownloadURL) }
        let htmlURL = decoded.htmlURL.flatMap { URL(string: $0) }

        return UpdateRelease(
            version: triple,
            tagName: decoded.tagName,
            zipURL: zipURL,
            shaURL: shaURL,
            htmlURL: htmlURL
        )
    }

    private func pickZipAsset(from assets: [GitHubAssetDTO], version: AppVersion.Triple) -> GitHubAssetDTO? {
        let preferred = preferredZipName(for: version)
        if let exact = assets.first(where: { $0.name == preferred }) {
            return exact
        }
        return assets.first {
            $0.name.hasSuffix(".zip")
                && $0.name.localizedCaseInsensitiveContains("macOS")
                && $0.name.localizedCaseInsensitiveContains("arm64")
        } ?? assets.first { $0.name.hasSuffix(".zip") && $0.name.localizedCaseInsensitiveContains("arm64") }
    }

    private func pickSHAAsset(from assets: [GitHubAssetDTO], zipName: String) -> GitHubAssetDTO? {
        let preferred = zipName + ".sha256"
        if let exact = assets.first(where: { $0.name == preferred }) {
            return exact
        }
        return assets.first { $0.name.hasSuffix(".sha256") }
    }

    private func preferredZipName(for version: AppVersion.Triple) -> String {
        "RenderPausePro-\(version.displayWithV)-macOS-arm64.zip"
    }

    private func loadExpectedSHA(for release: UpdateRelease) async throws -> String? {
        guard let shaURL = release.shaURL else { return nil }
        var request = URLRequest(url: shaURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        return AppVersion.parseSHA256Checksum(text)
    }

    private var userAgent: String {
        let v = AppVersion.localMarketing().display
        return "RenderPausePro/\(v) (+https://github.com/\(owner)/\(repo))"
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func shortError(_ error: Error) -> String {
        if let u = error as? UpdateError {
            return u.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络不可用"
            case .timedOut:
                return "检查超时"
            default:
                break
            }
        }
        return "检查失败"
    }
}

// MARK: - Errors / DTO

private enum UpdateError: LocalizedError {
    case httpStatus(Int)
    case badVersion(String)
    case missingZipAsset
    case missingChecksum
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "GitHub 响应 \(code)"
        case .badVersion:
            return "版本号无法解析"
        case .missingZipAsset:
            return "未找到安装包"
        case .missingChecksum:
            return "缺少校验文件"
        case .checksumMismatch:
            return "校验失败"
        }
    }
}

private struct GitHubReleaseDTO: Decodable {
    let tagName: String
    let htmlURL: String?
    let draft: Bool?
    let prerelease: Bool?
    let assets: [GitHubAssetDTO]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubAssetDTO: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

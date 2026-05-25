import Foundation

/// Result of an update check against the GitHub Releases API.
enum UpdateCheckResult {
    case upToDate(currentVersion: String)
    case updateAvailable(currentVersion: String, latestVersion: String, releaseURL: URL, downloadURL: URL?)
}

/// Errors that can occur while querying the GitHub Releases API.
enum UpdateCheckError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decoding
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response from the update server."
        case .httpStatus(let code):
            return "Update server returned HTTP \(code)."
        case .decoding:
            return "Could not parse the update information."
        case .network(let error):
            return error.localizedDescription
        }
    }
}

/// Queries the GitHub Releases API for the latest published release of MagicRing
/// and compares it against the bundle's marketing version.
struct UpdateChecker {
    /// GitHub repository owner.
    static let owner = "StaR4y"
    /// GitHub repository name.
    static let repository = "Magic-Ring"

    private let session: URLSession
    private let bundle: Bundle

    init(session: URLSession = .shared, bundle: Bundle = .main) {
        self.session = session
        self.bundle = bundle
    }

    /// Returns the marketing version baked into the running app bundle (CFBundleShortVersionString).
    var currentVersion: String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Performs a network request to GitHub and returns whether an update is available.
    func checkForUpdates() async throws -> UpdateCheckResult {
        let url = URL(string: "https://api.github.com/repos/\(Self.owner)/\(Self.repository)/releases/latest")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("MagicRing/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateCheckError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw UpdateCheckError.httpStatus(http.statusCode)
        }

        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateCheckError.decoding
        }

        let current = currentVersion
        let latest = Self.normalizedVersion(from: release.tagName)
        let releaseURL = URL(string: release.htmlURL) ?? URL(string: "https://github.com/\(Self.owner)/\(Self.repository)/releases")!
        let downloadURL = release.assets
            .first(where: { $0.name.hasSuffix(".dmg") })
            .flatMap { URL(string: $0.browserDownloadURL) }

        if Self.compareVersions(latest, current) == .orderedDescending {
            return .updateAvailable(
                currentVersion: current,
                latestVersion: latest,
                releaseURL: releaseURL,
                downloadURL: downloadURL
            )
        }

        return .upToDate(currentVersion: current)
    }

    // MARK: - Version helpers

    /// Strips a leading `v`/`V` and trims whitespace from a tag name.
    static func normalizedVersion(from tag: String) -> String {
        var trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first, first == "v" || first == "V" {
            trimmed.removeFirst()
        }
        return trimmed
    }

    /// Compares two dot-separated version strings numerically (e.g. `1.0.10` > `1.0.9`).
    /// Non-numeric segments fall back to lexicographic ordering for that segment.
    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsComponents = lhs.split(separator: ".").map(String.init)
        let rhsComponents = rhs.split(separator: ".").map(String.init)
        let count = max(lhsComponents.count, rhsComponents.count)

        for index in 0..<count {
            let leftRaw = index < lhsComponents.count ? lhsComponents[index] : "0"
            let rightRaw = index < rhsComponents.count ? rhsComponents[index] : "0"

            if let leftInt = Int(leftRaw), let rightInt = Int(rightRaw) {
                if leftInt < rightInt { return .orderedAscending }
                if leftInt > rightInt { return .orderedDescending }
            } else {
                let result = leftRaw.compare(rightRaw, options: .numeric)
                if result != .orderedSame { return result }
            }
        }

        return .orderedSame
    }
}

// MARK: - GitHub API DTOs

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}

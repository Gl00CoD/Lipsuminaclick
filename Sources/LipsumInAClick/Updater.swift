import AppKit
import LipsumCore

/// One-click updates from GitHub Releases, like ZuperZoeker:
/// "Update" checks the latest release; if it's newer, "Install and Restart" downloads the zip,
/// checks its signature, swaps the app in place and relaunches it.
@MainActor
final class Updater {
    static let repository = "Gl00CoD/Lipsuminaclick"
    /// Public half of the update signing key (the private half is the repo secret UPDATE_SIGNING_KEY).
    static let publicKey = "dWl+BcLmp3IRghUf/iw7+9s4KUOs/LN0YwFuM3fkG0k="
    static let zipAssetName = "LipsumInAClick.zip"
    static let signatureAssetName = "LipsumInAClick.zip.sig"
    static let releasesPage = URL(string: "https://github.com/\(repository)/releases/latest")!

    enum State {
        case idle
        case checking
        case downloading
    }

    /// Called whenever the state changes, so the menu can show progress.
    var onStateChange: ((State) -> Void)?

    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Lipsum in a Click"
    }

    private var currentVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: Checking

    func checkForUpdates() {
        guard case .idle = state else { return }
        state = .checking
        Task {
            let result: Result<Release?, Error>
            do {
                result = .success(try await fetchLatestRelease())
            } catch {
                result = .failure(error)
            }
            state = .idle
            handleCheckResult(result)
        }
    }

    private func handleCheckResult(_ result: Result<Release?, Error>) {
        switch result {
        case .failure(let error):
            showAlert(
                title: "Couldn't check for updates",
                message: "\(error.localizedDescription)\n\nAre you connected to the internet?",
                buttons: ["OK"]
            )

        case .success(nil):
            showAlert(
                title: "You're up to date",
                message: "No releases have been published yet. You have \(appName) \(currentVersionString).",
                buttons: ["OK"]
            )

        case .success(let release?):
            guard
                let latest = AppVersion(release.tagName),
                let current = AppVersion(currentVersionString),
                latest > current
            else {
                showAlert(
                    title: "You're up to date",
                    message: "\(appName) \(currentVersionString) is the latest version.",
                    buttons: ["OK"]
                )
                return
            }
            offer(release, version: latest)
        }
    }

    private func offer(_ release: Release, version: AppVersion) {
        let intro = "\(appName) \(version) is available (you have \(currentVersionString))."
        let notes = Self.trimmedNotes(release.body)
        let message = notes.isEmpty ? intro : "\(intro)\n\n\(notes)"

        guard
            let zip = release.asset(named: Self.zipAssetName),
            let signature = release.asset(named: Self.signatureAssetName)
        else {
            // Releases built without the signing key can't be installed automatically.
            let choice = showAlert(
                title: "Update available",
                message: message + "\n\nThis version can't be installed automatically. Download it from GitHub instead.",
                buttons: ["Download", "Later"]
            )
            if choice == .alertFirstButtonReturn { NSWorkspace.shared.open(release.pageURL) }
            return
        }

        let choice = showAlert(title: "Update available", message: message, buttons: ["Install and Restart", "Later"])
        guard choice == .alertFirstButtonReturn else { return }
        install(zipURL: zip, signatureURL: signature, version: version, release: release)
    }

    // MARK: Installing

    private func install(zipURL: URL, signatureURL: URL, version: AppVersion, release: Release) {
        let appURL = Bundle.main.bundleURL
        if let problem = locationProblem(for: appURL) {
            let choice = showAlert(title: "Can't update here", message: problem, buttons: ["Download Manually", "OK"])
            if choice == .alertFirstButtonReturn { NSWorkspace.shared.open(release.pageURL) }
            return
        }

        state = .downloading
        Task {
            do {
                let newApp = try await downloadAndPrepare(zipURL: zipURL, signatureURL: signatureURL, version: version, replacing: appURL)
                _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)
                relaunch(at: appURL)
            } catch {
                state = .idle
                let choice = showAlert(
                    title: "The update failed",
                    message: error.localizedDescription,
                    buttons: ["Download Manually", "OK"]
                )
                if choice == .alertFirstButtonReturn { NSWorkspace.shared.open(release.pageURL) }
            }
        }
    }

    /// Downloads and verifies the zip, unpacks it next to the app and returns the new .app.
    private func downloadAndPrepare(zipURL: URL, signatureURL: URL, version: AppVersion, replacing appURL: URL) async throws -> URL {
        let zipData = try await download(zipURL)
        let signatureData = try await download(signatureURL)
        let signature = String(decoding: signatureData, as: UTF8.self)

        guard UpdateSignature.isValid(data: zipData, signatureBase64: signature, publicKeyBase64: Self.publicKey) else {
            throw UpdateError("The download's signature doesn't match, so it wasn't installed.")
        }

        // A staging folder on the same disk as the app, so the swap is a simple rename.
        let staging = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: appURL,
            create: true
        )
        let zipFile = staging.appendingPathComponent(Self.zipAssetName)
        try zipData.write(to: zipFile)
        let extracted = staging.appendingPathComponent("extracted", isDirectory: true)
        try await Self.unzip(zipFile, to: extracted)

        let contents = try FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)
        guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError("The download didn't contain the app.")
        }

        let newInfo = Bundle(url: newApp)?.infoDictionary ?? [:]
        guard newInfo["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier else {
            throw UpdateError("The download contains a different app.")
        }
        guard
            let newVersionString = newInfo["CFBundleShortVersionString"] as? String,
            AppVersion(newVersionString) == version
        else {
            throw UpdateError("The download has an unexpected version number.")
        }
        return newApp
    }

    private func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError("The download failed (\((response as? HTTPURLResponse)?.statusCode ?? 0)).")
        }
        return data
    }

    private static func unzip(_ zip: URL, to destination: URL) async throws {
        let status: Int32 = try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", zip.path, destination.path]
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }.value
        guard status == 0 else { throw UpdateError("The download couldn't be unpacked.") }
    }

    /// Reasons the app can't replace itself where it is.
    private func locationProblem(for appURL: URL) -> String? {
        if appURL.path.contains("/AppTranslocation/") {
            return "Move \(appName) to your Applications folder, open it from there, and try again."
        }
        let folder = appURL.deletingLastPathComponent().path
        if !FileManager.default.isWritableFile(atPath: folder) || !FileManager.default.isWritableFile(atPath: appURL.path) {
            return "\(appName) isn't allowed to replace itself in \(folder). Move it to your Applications folder, or download the update manually."
        }
        return nil
    }

    /// Waits for this process to quit, then opens the (now updated) app again.
    private func relaunch(at appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", appURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: GitHub

    private func fetchLatestRelease() async throws -> Release? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("LipsumInAClick/\(currentVersionString)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }  // no releases yet
        guard status == 200 else { throw UpdateError("GitHub answered with status \(status).") }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let body: String?
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }

        var pageURL: URL { htmlURL }

        func asset(named name: String) -> URL? {
            assets.first(where: { $0.name == name })?.browserDownloadURL
        }
    }

    // MARK: Helpers

    /// Release notes for the alert: this version's notes only, a few lines at most.
    private static func trimmedNotes(_ body: String?) -> String {
        guard let body else { return "" }
        let ownNotes = body.components(separatedBy: "## Earlier versions").first ?? body
        let lines = ownNotes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("---") }
            .prefix(8)
        return lines.joined(separator: "\n")
    }

    @discardableResult
    private func showAlert(title: String, message: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for button in buttons { alert.addButton(withTitle: button) }
        // Menu bar apps aren't frontmost by default; bring the alert forward.
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}

struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

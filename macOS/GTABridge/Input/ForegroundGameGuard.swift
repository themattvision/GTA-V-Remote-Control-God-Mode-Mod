import AppKit
import Foundation

struct ForegroundApplicationSnapshot: Equatable, Sendable {
    let processIdentifier: pid_t
    let bundleURL: URL?
    let executableURL: URL?
    let localizedName: String?
}

@MainActor
protocol ForegroundApplicationProviding {
    func frontmostApplication() -> ForegroundApplicationSnapshot?
}

@MainActor
struct WorkspaceForegroundApplicationProvider: ForegroundApplicationProviding {
    func frontmostApplication() -> ForegroundApplicationSnapshot? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return ForegroundApplicationSnapshot(
            processIdentifier: application.processIdentifier,
            bundleURL: application.bundleURL,
            executableURL: application.executableURL,
            localizedName: application.localizedName
        )
    }
}

enum ForegroundGameGuardError: Error, Equatable, LocalizedError {
    case noFrontmostApplication
    case unexpectedBundle(URL?)
    case unexpectedExecutable(String?)

    var errorDescription: String? {
        switch self {
        case .noFrontmostApplication:
            "Nessuna applicazione in primo piano."
        case .unexpectedBundle:
            "GTA V non e l'applicazione in primo piano."
        case .unexpectedExecutable:
            "Il processo in primo piano non appartiene all'installazione GTA autorizzata."
        }
    }
}

@MainActor
protocol ForegroundGameChecking {
    func validateForegroundGame() throws
}

@MainActor
struct ForegroundGameGuard<Provider: ForegroundApplicationProviding>: ForegroundGameChecking {
    static var verifiedBundleURL: URL {
        URL(fileURLWithPath: "/Volumes/SSD GAMES/Grand Theft Auto V.app", isDirectory: true)
    }

    private static var allowedExecutableNames: Set<String> {
        [
            "gta5.exe",
            "wine",
            "wine64",
            "wine64-preloader",
            "wineskinlauncher",
            "wineskinlauncher32bit",
            "wineskinlauncher64bit",
        ]
    }

    private let provider: Provider
    private let expectedBundleURL: URL

    init(
        provider: Provider,
        expectedBundleURL: URL = Self.verifiedBundleURL
    ) {
        self.provider = provider
        self.expectedBundleURL = expectedBundleURL
    }

    func validateForegroundGame() throws {
        guard let application = provider.frontmostApplication() else {
            throw ForegroundGameGuardError.noFrontmostApplication
        }

        let expectedBundle = canonicalURL(expectedBundleURL)
        guard let bundleURL = application.bundleURL,
              urlIsInsideVerifiedBundle(bundleURL, bundleURL: expectedBundle) else {
            throw ForegroundGameGuardError.unexpectedBundle(application.bundleURL)
        }

        guard let executableURL = application.executableURL,
              urlIsInsideVerifiedBundle(executableURL, bundleURL: expectedBundle),
              Self.allowedExecutableNames.contains(executableURL.lastPathComponent.lowercased()) else {
            throw ForegroundGameGuardError.unexpectedExecutable(
                application.executableURL?.lastPathComponent
            )
        }
    }

    private func urlIsInsideVerifiedBundle(_ url: URL, bundleURL: URL) -> Bool {
        let executablePath = canonicalURL(url).path
        let bundlePath = bundleURL.path.hasSuffix("/") ? bundleURL.path : bundleURL.path + "/"
        return executablePath == bundleURL.path || executablePath.hasPrefix(bundlePath)
    }

    private func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}

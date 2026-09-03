import Foundation
import Testing
@testable import GTABridge

@MainActor
struct ForegroundGameGuardTests {
    private let expectedBundle = URL(fileURLWithPath: "/Volumes/Test/Grand Theft Auto V.app")

    @Test
    func acceptsWineExecutableInsideVerifiedBundle() throws {
        let provider = StubForegroundApplicationProvider(
            snapshot: snapshot(
                bundleURL: expectedBundle.appending(path: "Contents/SharedSupport/wine/bin/wine"),
                executableURL: expectedBundle.appending(path: "Contents/Frameworks/wine64-preloader")
            )
        )
        let guardUnderTest = ForegroundGameGuard(
            provider: provider,
            expectedBundleURL: expectedBundle
        )

        try guardUnderTest.validateForegroundGame()
    }

    @Test
    func rejectsOtherFrontmostApplication() {
        let otherBundle = URL(fileURLWithPath: "/Applications/Notes.app")
        let provider = StubForegroundApplicationProvider(
            snapshot: snapshot(
                bundleURL: otherBundle,
                executableURL: otherBundle.appending(path: "Contents/MacOS/Notes")
            )
        )
        let guardUnderTest = ForegroundGameGuard(
            provider: provider,
            expectedBundleURL: expectedBundle
        )

        #expect(throws: ForegroundGameGuardError.self) {
            try guardUnderTest.validateForegroundGame()
        }
    }

    @Test
    func rejectsUnexpectedExecutableEvenInsideVerifiedBundle() {
        let provider = StubForegroundApplicationProvider(
            snapshot: snapshot(
                bundleURL: expectedBundle,
                executableURL: expectedBundle.appending(path: "Contents/MacOS/helper")
            )
        )
        let guardUnderTest = ForegroundGameGuard(
            provider: provider,
            expectedBundleURL: expectedBundle
        )

        #expect(throws: ForegroundGameGuardError.self) {
            try guardUnderTest.validateForegroundGame()
        }
    }

    private func snapshot(bundleURL: URL, executableURL: URL) -> ForegroundApplicationSnapshot {
        ForegroundApplicationSnapshot(
            processIdentifier: 42,
            bundleURL: bundleURL,
            executableURL: executableURL,
            localizedName: "Grand Theft Auto V"
        )
    }
}

@MainActor
private struct StubForegroundApplicationProvider: ForegroundApplicationProviding {
    let snapshot: ForegroundApplicationSnapshot?

    func frontmostApplication() -> ForegroundApplicationSnapshot? {
        snapshot
    }
}

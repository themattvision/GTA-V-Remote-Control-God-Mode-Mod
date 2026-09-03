@preconcurrency import ApplicationServices
import Foundation
import Observation

enum AccessibilityPermissionState: Equatable, Sendable {
    case unknown
    case denied
    case granted
}

@MainActor
protocol AccessibilityTrustChecking {
    func isTrusted() -> Bool
    func requestTrustPrompt() -> Bool
}

@MainActor
struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    private let trustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"

    func isTrusted() -> Bool {
        let options: CFDictionary = [trustedCheckOptionPromptKey: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestTrustPrompt() -> Bool {
        let options: CFDictionary = [trustedCheckOptionPromptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

@Observable
@MainActor
final class AccessibilityPermission<Checker: AccessibilityTrustChecking> {
    private(set) var state: AccessibilityPermissionState = .unknown

    private let checker: Checker
    private var pollingTask: Task<Void, Never>?

    init(checker: Checker) {
        self.checker = checker
        refresh()
        startPolling()
    }

    func refresh() {
        state = checker.isTrusted() ? .granted : .denied
    }

    func request() {
        state = checker.requestTrustPrompt() ? .granted : .denied
        startPolling()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let isTrusted = self?.checker.isTrusted() else { return }
                self?.state = isTrusted ? .granted : .denied
                if isTrusted {
                    return
                }

                try? await ContinuousClock().sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

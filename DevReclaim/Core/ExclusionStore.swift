import Foundation
import Observation

/// Persists paths the user has chosen to permanently skip during scans.
@Observable
class ExclusionStore {
    private let defaultsKey = "devreclaim.excludedPaths"
    private(set) var excludedPaths: Set<String> = []

    init() { load() }

    func exclude(_ url: URL) {
        excludedPaths.insert(url.path)
        save()
    }

    func unexclude(_ url: URL) {
        excludedPaths.remove(url.path)
        save()
    }

    func isExcluded(_ url: URL) -> Bool {
        excludedPaths.contains(url.path)
    }

    private func save() {
        UserDefaults.standard.set(Array(excludedPaths), forKey: defaultsKey)
    }

    private func load() {
        excludedPaths = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }
}

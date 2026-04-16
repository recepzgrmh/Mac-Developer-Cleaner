import Foundation
import Observation

/// Persists paths the user has chosen to permanently skip during scans.
@Observable
class ExclusionStore {
    private let defaultsKey = "devreclaim.excludedPaths"
    private(set) var excludedPaths: Set<String> = []

    init() { load() }

    func exclude(_ url: URL) {
        excludedPaths.insert(normalize(url))
        save()
    }

    func unexclude(_ url: URL) {
        excludedPaths.remove(normalize(url))
        save()
    }

    func isExcluded(_ url: URL) -> Bool {
        let candidate = normalize(url)
        return excludedPaths.contains { excluded in
            candidate == excluded || candidate.hasPrefix(excluded + "/")
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(excludedPaths), forKey: defaultsKey)
    }

    private func load() {
        let loaded = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        excludedPaths = Set(loaded.map { normalize(path: $0) })
    }

    private func normalize(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func normalize(path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

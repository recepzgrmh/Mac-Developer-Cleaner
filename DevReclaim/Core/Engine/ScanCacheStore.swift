import Foundation
import OSLog

protocol ScanCacheStoreProtocol {
    func load() -> ScanCacheSnapshot?
    func save(_ snapshot: ScanCacheSnapshot)
}

final class ScanCacheStore: ScanCacheStoreProtocol {
    private let cacheURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let logger = Logger(subsystem: "DevReclaim", category: "ScanCacheStore")

    init(cacheURL: URL? = nil) {
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("DevReclaim")
            do {
                try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create app support directory: \(error.localizedDescription)")
            }
            self.cacheURL = appDir.appendingPathComponent("scan-cache.json")
        }
        encoder.outputFormatting = [.prettyPrinted]
    }

    func load() -> ScanCacheSnapshot? {
        do {
            let data = try Data(contentsOf: cacheURL)
            return try decoder.decode(ScanCacheSnapshot.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            logger.error("Failed to load scan cache: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ snapshot: ScanCacheSnapshot) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            logger.error("Failed to save scan cache: \(error.localizedDescription)")
        }
    }
}

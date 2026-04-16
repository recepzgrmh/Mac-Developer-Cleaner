import Foundation

// MARK: - Enums

/// Method used to detect if a preset's target exists on disk.
enum DetectionMethod: String, Codable {
    case directory_exists
    case glob_match
}

/// Available execution modes for reclaiming space.
enum ExecutionMode: String, Codable {
    case native
    case trash
    case delete
}

/// Strategy used to calculate the size of a target during dry-run.
enum DryRunStrategy: String, Codable {
    case measure_directory
    case measure_hardlink_aware
}

/// Confidence level of the reclamation process.
enum ReclaimConfidence: String, Codable {
    case high
    case low
}

/// Risk associated with deleting the target.
enum RiskLevel: String, Codable {
    case safe
    case usuallySafe
    case reviewFirst
    case neverAuto
}

/// Action to take if the primary execution mode fails.
enum FallbackAction: String, Codable {
    case prompt_for_trash
    case none
}

/// Rules applied to ensure scanning stays within safe boundaries.
enum GuardrailRule: String, Codable {
    case must_be_outside_project_boundary
}

/// Current status of a scan target.
enum ScanStatus: String, Codable, Equatable {
    case unscanned
    case discovered
    case calculating
    case ready
    case timedOut
    case failed
}

// MARK: - Preset Model

/// A definition of a reclaimable target, including how to detect, measure, and clean it.
struct Preset: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let pathResolver: String
    let detectionMethod: DetectionMethod
    let supportedExecutionModes: [ExecutionMode]
    let dryRunStrategy: DryRunStrategy
    let reclaimConfidence: ReclaimConfidence
    let requiresToolInstalled: String?
    let riskLevel: RiskLevel
    let reviewReason: String?
    let guardrailRules: [GuardrailRule]
    let explanation: String
    let executionType: ExecutionMode
    let nativeCommand: String?
    let fallbackAction: FallbackAction
}

// MARK: - Scanning Data

/// A specific location on disk that matches a preset and is a candidate for reclamation.
struct ScanTarget: Identifiable, Equatable, Codable {
    let id: UUID
    let url: URL
    let matchingPresetId: String?
    /// For project_artifact targets: the root project directory that contains this artifact.
    let projectURL: URL?
    var allocatedSizeInBytes: Int64
    var status: ScanStatus
    var lastAccessDate: Date?
    var lastMeasuredAt: Date?
    var isSizeEstimate: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        matchingPresetId: String?,
        projectURL: URL? = nil,
        allocatedSizeInBytes: Int64 = 0,
        status: ScanStatus = .unscanned,
        lastAccessDate: Date? = nil,
        lastMeasuredAt: Date? = nil,
        isSizeEstimate: Bool = false
    ) {
        self.id = id
        self.url = url
        self.matchingPresetId = matchingPresetId
        self.projectURL = projectURL
        self.allocatedSizeInBytes = allocatedSizeInBytes
        self.status = status
        self.lastAccessDate = lastAccessDate
        self.lastMeasuredAt = lastMeasuredAt
        self.isSizeEstimate = isSizeEstimate
    }
    
    static func == (lhs: ScanTarget, rhs: ScanTarget) -> Bool {
        lhs.id == rhs.id
    }
}

extension ScanTarget {
    /// Stable identity that uniquely distinguishes identical paths matched by different presets.
    var identityKey: String {
        "\(matchingPresetId ?? "_")::\(url.path)"
    }

    var relativeLastAccessDescription: String? {
        guard let lastAccessDate else { return nil }
        return RelativeDateTimeFormatter().localizedString(for: lastAccessDate, relativeTo: Date())
    }
}

/// A single file/folder sample shown to the user before reclaiming space.
struct DryRunPreviewItem: Identifiable, Equatable, Codable {
    let path: String
    let allocatedSizeInBytes: Int64
    let isDirectory: Bool

    var id: String { path }
}

/// Summarizes what would be deleted for a specific target.
struct DryRunPreview: Equatable, Codable {
    let targetPath: String
    let generatedAt: Date
    let totalItems: Int
    let estimatedTotalBytes: Int64
    let isTruncated: Bool
    let items: [DryRunPreviewItem]
}

/// Represents a large file candidate (installer, partial download, or generic large file).
struct LargeFileHit: Identifiable, Equatable, Codable {
    let path: String
    let allocatedSizeInBytes: Int64
    let lastAccessDate: Date?
    let reason: String

    var id: String { path }
}

/// Aggregated project artifact view model built from scan targets.
struct ProjectBreakdownGroup: Identifiable, Equatable {
    let projectURL: URL
    let name: String
    let targets: [ScanTarget]
    let totalBytes: Int64

    var id: String { projectURL.path }
}

/// Persisted snapshot to provide instant results on app startup.
struct ScanCacheSnapshot: Codable {
    let savedAt: Date
    let scanTargets: [ScanTarget]
    let largeFileHits: [LargeFileHit]
    let skippedExcludedCount: Int
    let timedOutTargetCount: Int
    let warnings: [String]
}

// MARK: - Auditing Data

/// The result of an execution attempt to reclaim space.
struct ExecutionReport: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let presetId: String
    let executionMode: ExecutionMode
    let recoveredBytes: Int64
    let wasSuccess: Bool
    let errorMessage: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), presetId: String, executionMode: ExecutionMode, recoveredBytes: Int64, wasSuccess: Bool, errorMessage: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.presetId = presetId
        self.executionMode = executionMode
        self.recoveredBytes = recoveredBytes
        self.wasSuccess = wasSuccess
        self.errorMessage = errorMessage
    }
}

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
struct ScanTarget: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let matchingPresetId: String?
    var allocatedSizeInBytes: Int64
    var status: ScanStatus
    
    init(id: UUID = UUID(), url: URL, matchingPresetId: String?, allocatedSizeInBytes: Int64 = 0, status: ScanStatus = .unscanned) {
        self.id = id
        self.url = url
        self.matchingPresetId = matchingPresetId
        self.allocatedSizeInBytes = allocatedSizeInBytes
        self.status = status
    }
    
    static func == (lhs: ScanTarget, rhs: ScanTarget) -> Bool {
        lhs.id == rhs.id
    }
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

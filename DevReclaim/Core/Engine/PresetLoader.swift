import Foundation

protocol PresetLoaderProtocol {
    func loadEmbeddedPresets() throws -> [Preset]
}

class PresetLoader: PresetLoaderProtocol {
    func loadEmbeddedPresets() throws -> [Preset] {
        // In Phase 1 Minimum Vertical Slice, we return hardcoded presets.
        // In later phases, this could be loaded from an embedded JSON or Remote Config.
        
        let npmPreset = Preset(
            id: "npm_global_cache",
            name: "npm Global Cache",
            category: "global_cache",
            pathResolver: "~/.npm",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.native, .trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "npm",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Holds downloaded npm packages. Safe to delete. The next installation will re-download required data.",
            executionType: .native,
            nativeCommand: "npm cache clean --force",
            fallbackAction: .prompt_for_trash
        )
        
        let dartPubPreset = Preset(
            id: "dart_pub_cache",
            name: "Dart / Flutter Pub Cache",
            category: "global_cache",
            pathResolver: "~/.pub-cache",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.native, .trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "dart",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Holds downloaded Dart/Flutter packages. Re-downloaded when building/running. Running 'dart pub cache clean' is the safest way.",
            executionType: .native,
            nativeCommand: "dart pub cache clean",
            fallbackAction: .prompt_for_trash
        )
        
        let cocoaPodsPreset = Preset(
            id: "cocoapods_cache",
            name: "CocoaPods Cache",
            category: "global_cache",
            pathResolver: "~/Library/Caches/CocoaPods",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.native, .trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "pod",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Holds downloaded CocoaPods dependencies. Safe to delete, will be re-downloaded during 'pod install'.",
            executionType: .native,
            nativeCommand: "pod cache clean --all",
            fallbackAction: .prompt_for_trash
        )
        
        let gradlePreset = Preset(
            id: "gradle_user_cache",
            name: "Gradle User Cache",
            category: "global_cache",
            pathResolver: "~/.gradle",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Holds downloaded Gradle dependencies and wrapper distributions. Safe to delete, will be re-downloaded as needed.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )
        
        let xcodePreset = Preset(
            id: "xcode_derived_data",
            name: "Xcode DerivedData",
            category: "global_cache",
            pathResolver: "~/Library/Developer/Xcode/DerivedData",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Contains build artifacts and indexes for Xcode projects. Safe to delete, will be rebuilt on next compilation.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )
        
        let projectBuildPreset = Preset(
            id: "project_build_dir",
            name: "Project Build Folder",
            category: "project_artifact",
            pathResolver: "build",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .usuallySafe,
            reviewReason: "This folder contains build output for the current project.",
            guardrailRules: [],
            explanation: "Generic build output folder. Rebuilt during next compilation.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )
        
        let dartToolPreset = Preset(
            id: "dart_tool_dir",
            name: "Dart Tool Artifacts",
            category: "project_artifact",
            pathResolver: ".dart_tool",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .usuallySafe,
            reviewReason: "Contains generated artifacts for Dart/Flutter projects.",
            guardrailRules: [],
            explanation: "Safe to delete, Flutter will recreate this on the next run.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )
        
        let nodeModulesPreset = Preset(
            id: "node_modules_dir",
            name: "Node Modules",
            category: "project_artifact",
            pathResolver: "node_modules",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .reviewFirst,
            reviewReason: "Contains project dependencies. Deleting requires running npm install again.",
            guardrailRules: [],
            explanation: "Heavy folder containing project dependencies. Safe to delete but requires re-installation.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        return [
            npmPreset,
            dartPubPreset,
            cocoaPodsPreset,
            gradlePreset,
            xcodePreset,
            projectBuildPreset,
            dartToolPreset,
            nodeModulesPreset
        ]
    }
}

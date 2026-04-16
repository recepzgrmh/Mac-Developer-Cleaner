import Foundation

protocol PresetLoaderProtocol {
    func loadEmbeddedPresets() throws -> [Preset]
}

class PresetLoader: PresetLoaderProtocol {
    func loadEmbeddedPresets() throws -> [Preset] {
        // Global caches
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

        let cargoRegistryPreset = Preset(
            id: "rust_cargo_registry_cache",
            name: "Rust Cargo Registry",
            category: "global_cache",
            pathResolver: "~/.cargo/registry",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "cargo",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Downloaded Cargo crates cache. Safe to clear; crates are fetched again when needed.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let cargoGitPreset = Preset(
            id: "rust_cargo_git_cache",
            name: "Rust Cargo Git Cache",
            category: "global_cache",
            pathResolver: "~/.cargo/git",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "cargo",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Git checkouts used by Cargo. Safe to remove; dependencies are fetched again on demand.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let goModulesPreset = Preset(
            id: "go_modules_cache",
            name: "Go Modules Cache",
            category: "global_cache",
            pathResolver: "~/go/pkg/mod",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "go",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Downloaded Go modules cache. Safe to delete; modules are restored by go commands.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let pipCachePreset = Preset(
            id: "python_pip_cache",
            name: "Python pip Cache",
            category: "global_cache",
            pathResolver: "~/Library/Caches/pip",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "python3",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Package download cache for pip. Safe to delete; pip re-downloads when required.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let poetryCachePreset = Preset(
            id: "python_poetry_cache",
            name: "Poetry Cache",
            category: "global_cache",
            pathResolver: "~/Library/Caches/pypoetry",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "poetry",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Poetry package and metadata cache. Safe to clear; poetry restores it as needed.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let condaCachePreset = Preset(
            id: "python_conda_pkgs_cache",
            name: "Conda Package Cache",
            category: "global_cache",
            pathResolver: "~/miniconda3/pkgs",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "conda",
            riskLevel: .reviewFirst,
            reviewReason: "Conda environments may need to re-fetch package archives after cleanup.",
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Conda package archive cache. Usually safe to clear, but expect package re-downloads.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let dockerBuildxPreset = Preset(
            id: "docker_buildx_cache",
            name: "Docker BuildX Cache",
            category: "global_cache",
            pathResolver: "~/.docker/buildx",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "docker",
            riskLevel: .usuallySafe,
            reviewReason: "Rebuilding images will take longer after cleanup.",
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Layer cache used by Docker buildx. Safe to remove if you can tolerate slower next builds.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let mavenPreset = Preset(
            id: "maven_local_repo_cache",
            name: "Maven Local Repository",
            category: "global_cache",
            pathResolver: "~/.m2/repository",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "mvn",
            riskLevel: .usuallySafe,
            reviewReason: "Maven dependencies will be downloaded again on next build.",
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Local Maven dependency store. Safe to remove with expected re-download on next build.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let sbtPreset = Preset(
            id: "sbt_cache",
            name: "SBT Cache",
            category: "global_cache",
            pathResolver: "~/.sbt",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "sbt",
            riskLevel: .usuallySafe,
            reviewReason: "SBT may need to restore build metadata and dependencies.",
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "SBT and plugin cache. Usually safe to clean when reclaiming disk space.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let jetBrainsToolboxPreset = Preset(
            id: "jetbrains_toolbox_apps_cache",
            name: "JetBrains Toolbox Apps Cache",
            category: "global_cache",
            pathResolver: "~/Library/Application Support/JetBrains/Toolbox/apps",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .low,
            requiresToolInstalled: nil,
            riskLevel: .reviewFirst,
            reviewReason: "Can contain app versions and installation artifacts managed by Toolbox.",
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "JetBrains Toolbox app storage. Review before deleting to avoid removing active IDE installs.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        // Project artifacts
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

        let rustTargetPreset = Preset(
            id: "rust_target_dir",
            name: "Rust Target Folder",
            category: "project_artifact",
            pathResolver: "target",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .usuallySafe,
            reviewReason: "Contains Rust compilation outputs and incremental caches.",
            guardrailRules: [],
            explanation: "Rust build artifacts. Safe to remove when reclaiming space.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let distPreset = Preset(
            id: "project_dist_dir",
            name: "Project Dist Folder",
            category: "project_artifact",
            pathResolver: "dist",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .usuallySafe,
            reviewReason: "Contains generated distribution bundles.",
            guardrailRules: [],
            explanation: "Distribution build outputs. Usually safe to regenerate.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        // System caches
        let xcodeDeviceSupportPreset = Preset(
            id: "xcode_ios_device_support",
            name: "Xcode iOS Device Support",
            category: "system_cache",
            pathResolver: "~/Library/Developer/Xcode/iOS DeviceSupport",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Xcode downloads debug symbol files for each iOS version used on a real device. Old version folders are safe to delete; Xcode re-downloads them when needed.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let xcodeSimulatorCachesPreset = Preset(
            id: "xcode_simulator_caches",
            name: "Xcode Simulator Caches",
            category: "system_cache",
            pathResolver: "~/Library/Developer/CoreSimulator/Caches",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: nil,
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Cached data generated by iOS Simulator runs. Safe to delete; simulators regenerate these caches on next use.",
            executionType: .trash,
            nativeCommand: nil,
            fallbackAction: .none
        )

        let homebrewCachePreset = Preset(
            id: "homebrew_downloads_cache",
            name: "Homebrew Downloads Cache",
            category: "system_cache",
            pathResolver: "~/Library/Caches/Homebrew",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.native, .trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .high,
            requiresToolInstalled: "brew",
            riskLevel: .safe,
            reviewReason: nil,
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "Holds downloaded formula and cask archives used by Homebrew. Safe to delete; Homebrew re-downloads packages as needed.",
            executionType: .native,
            nativeCommand: "brew cleanup --prune=all",
            fallbackAction: .prompt_for_trash
        )

        let macOSAppCachesPreset = Preset(
            id: "macos_app_caches",
            name: "macOS App Caches",
            category: "system_cache",
            pathResolver: "~/Library/Caches",
            detectionMethod: .directory_exists,
            supportedExecutionModes: [.trash],
            dryRunStrategy: .measure_directory,
            reclaimConfidence: .low,
            requiresToolInstalled: nil,
            riskLevel: .reviewFirst,
            reviewReason: "Contains caches for many apps at once. Deleting the entire folder may temporarily slow down some applications until they rebuild their caches.",
            guardrailRules: [.must_be_outside_project_boundary],
            explanation: "macOS stores per-app cache files here. Deleting can free significant space; apps rebuild caches automatically on next launch.",
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
            cargoRegistryPreset,
            cargoGitPreset,
            goModulesPreset,
            pipCachePreset,
            poetryCachePreset,
            condaCachePreset,
            dockerBuildxPreset,
            mavenPreset,
            sbtPreset,
            jetBrainsToolboxPreset,
            projectBuildPreset,
            dartToolPreset,
            nodeModulesPreset,
            rustTargetPreset,
            distPreset,
            xcodeDeviceSupportPreset,
            xcodeSimulatorCachesPreset,
            homebrewCachePreset,
            macOSAppCachesPreset
        ]
    }
}

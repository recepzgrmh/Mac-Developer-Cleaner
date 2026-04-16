import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    let onFullHomeScanSelected: (Bool) -> Void
    @State private var step: Int = 0

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                Group {
                    switch step {
                    case 0:
                        genericStep(
                            icon: "internaldrive.fill",
                            iconColor: .accentColor,
                            title: "Welcome to DevReclaim",
                            message: "Safely reclaim gigabytes of disk space from developer caches, build artifacts, and system caches — all from one place, with full control over what gets deleted.",
                            primaryLabel: "Get Started",
                            primaryAction: advance
                        )
                    case 1:
                        PermissionStepContent(onContinue: advance)
                    case 2:
                        ScanScopeStepContent(
                            onChooseBalanced: {
                                onFullHomeScanSelected(false)
                                advance()
                            },
                            onChooseComprehensive: {
                                onFullHomeScanSelected(true)
                                advance()
                            }
                        )
                    default:
                        genericStep(
                            icon: "checkmark.seal.fill",
                            iconColor: .green,
                            title: "You're All Set",
                            message: "Select a category in the sidebar and press ⌘R to scan. DevReclaim shows exactly how much space you can reclaim before anything is deleted.",
                            primaryLabel: "Start Cleaning",
                            primaryAction: onComplete
                        )
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 20)

                progressDots
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 480, idealWidth: 480, maxWidth: 480, minHeight: 420)
    }

    // MARK: - Generic step layout

    @ViewBuilder
    private func genericStep(
        icon: String,
        iconColor: Color,
        title: String,
        message: String,
        primaryLabel: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: 26, weight: .bold))

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 340)
                .lineSpacing(3)

            Button(primaryLabel, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: i == step ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: step)
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.22)) {
            step += 1
        }
    }
}

// MARK: - Permission Step

private struct PermissionStepContent: View {
    let onContinue: () -> Void
    @State private var fdaGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: fdaGranted ? "checkmark.shield.fill" : "lock.fill")
                .font(.system(size: 56))
                .foregroundColor(fdaGranted ? .green : .orange)
                .animation(.easeInOut, value: fdaGranted)

            Text("Full Disk Access")
                .font(.system(size: 26, weight: .bold))

            Text("DevReclaim needs Full Disk Access to scan all cache folders on your Mac. Without it, protected locations such as ~/Library may be partially skipped.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 340)
                .lineSpacing(3)

            if fdaGranted {
                Label("Full Disk Access granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline.bold())

                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                HStack(spacing: 16) {
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Skip for Now", action: onContinue)
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 40)
        .onAppear { checkFDA() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            // Re-check when the user returns from System Settings
            checkFDA()
        }
    }

    private func checkFDA() {
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        fdaGranted = FileManager.default.isReadableFile(atPath: testPath.path)
    }
}

// MARK: - Scan Scope Step

private struct ScanScopeStepContent: View {
    let onChooseBalanced: () -> Void
    let onChooseComprehensive: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "scope")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Choose Scan Scope")
                .font(.system(size: 26, weight: .bold))

            Text("Would you like DevReclaim to also scan your entire Home folder (`~`) for project artifacts? This finds more reclaimable files, but scans can take longer.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 360)
                .lineSpacing(3)

            VStack(spacing: 10) {
                Button("Use Comprehensive Scan") {
                    onChooseComprehensive()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Keep Balanced Default Scan") {
                    onChooseBalanced()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 40)
    }
}

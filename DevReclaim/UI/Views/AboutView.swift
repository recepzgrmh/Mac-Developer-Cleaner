import SwiftUI
import AppKit

struct AboutView: View {
    private let appName = "DevReclaim"
    private let stageLabel = "Version 1.0 Alpha"
    private let developerName = "Recep Özgür Mıh"

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (short, build) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return "1.0"
        }
    }

    private var logoImage: NSImage? {
        if let image = NSImage(named: NSImage.Name("AppDockIcon")) ??
            NSImage(named: NSImage.Name("AppIcon")) {
            return image
        }
        if let url = Bundle.module.url(forResource: "AppDockIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: "AppDockIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 16) {
                    Group {
                        if let logoImage {
                            Image(nsImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "internaldrive.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.secondary)
                                .padding(20)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appName)
                            .font(.system(size: 34, weight: .bold))
                        Text(stageLabel)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Build \(versionString)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }

                aboutCard(
                    title: "What This App Does",
                    body: "DevReclaim helps developers find heavy caches, build artifacts, and temporary files, then reclaim disk space from a single screen."
                )

                aboutCard(
                    title: "How It Works",
                    body: "The app scans global caches, system caches, and local project artifacts, then shows estimated reclaimable space before permanent deletion."
                )

                aboutCard(
                    title: "Safety Model",
                    body: "Before deletion, DevReclaim shows a clear confirmation sheet with the items to be removed. You always make the final decision."
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Developer")
                        .font(.headline)
                    Text(developerName)
                        .font(.body)
                    Text("First public version of this app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func aboutCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

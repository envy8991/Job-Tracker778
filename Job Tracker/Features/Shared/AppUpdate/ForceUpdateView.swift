import SwiftUI

struct ForceUpdateView: View {
    let requirement: AppUpdateRequirement
    let currentVersion: String
    let currentBuild: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemIndigo), Color(.systemBlue), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)

                VStack(spacing: 10) {
                    Text("Update Required")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("A newer version of Job Tracker is available. Please update to continue using the app.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Installed: \(currentVersion) (\(currentBuild))", systemImage: "iphone")
                    Label("Available: \(requirement.latestVersion)\(availableBuildText)", systemImage: "sparkles")

                    if let releaseNotes = requirement.releaseNotes, !releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        Text(releaseNotes)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.primary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button(action: openUpdateURL) {
                    Text("Update Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(requirement.updateURL == nil)

                if requirement.updateURL == nil {
                    Text("Ask your administrator for the latest install link.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
            .frame(maxWidth: 520)
        }
        .interactiveDismissDisabled(true)
        .accessibilityIdentifier("ForceUpdateView")
    }

    private var availableBuildText: String {
        guard let latestBuild = requirement.latestBuild else { return "" }
        return " (\(latestBuild))"
    }

    private func openUpdateURL() {
        guard let updateURL = requirement.updateURL else { return }
        openURL(updateURL)
    }
}

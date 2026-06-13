import SwiftUI

struct ForceUpdateViewContent: Equatable {
    let title: String
    let message: String
    let installedText: String
    let availableText: String
    let releaseNotes: String?
    let buttonTitle: String
    let isUpdateButtonEnabled: Bool
    let missingUpdateURLMessage: String?
    let accessibilityIdentifier: String

    init(requirement: AppUpdateRequirement, currentVersion: String, currentBuild: String) {
        title = "Update Required"
        message = "A newer version of Job Tracker is available. Please update to continue using the app."
        installedText = "Installed: \(currentVersion) (\(currentBuild))"
        if let latestBuild = requirement.latestBuild {
            availableText = "Available: \(requirement.latestVersion) (\(latestBuild))"
        } else {
            availableText = "Available: \(requirement.latestVersion)"
        }
        let trimmedNotes = requirement.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        releaseNotes = trimmedNotes?.isEmpty == false ? trimmedNotes : nil
        buttonTitle = "Update Now"
        isUpdateButtonEnabled = requirement.updateURL != nil
        missingUpdateURLMessage = requirement.updateURL == nil ? "Ask your administrator for the latest install link." : nil
        accessibilityIdentifier = "ForceUpdateView"
    }
}

struct ForceUpdateView: View {
    let requirement: AppUpdateRequirement
    let currentVersion: String
    let currentBuild: String

    @Environment(\.openURL) private var openURL

    private var content: ForceUpdateViewContent {
        ForceUpdateViewContent(
            requirement: requirement,
            currentVersion: currentVersion,
            currentBuild: currentBuild
        )
    }

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
                    Text(content.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(content.message)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(content.installedText, systemImage: "iphone")
                    Label(content.availableText, systemImage: "sparkles")

                    if let releaseNotes = content.releaseNotes {
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
                    Text(content.buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!content.isUpdateButtonEnabled)
                .accessibilityIdentifier("ForceUpdateView.UpdateNowButton")

                if let missingUpdateURLMessage = content.missingUpdateURLMessage {
                    Text(missingUpdateURLMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
            .frame(maxWidth: 520)
        }
        .interactiveDismissDisabled(true)
        .accessibilityIdentifier(content.accessibilityIdentifier)
    }

    private func openUpdateURL() {
        guard let updateURL = requirement.updateURL else { return }
        openURL(updateURL)
    }
}

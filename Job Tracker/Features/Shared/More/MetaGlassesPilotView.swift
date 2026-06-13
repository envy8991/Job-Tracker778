import SwiftUI

struct MetaGlassesPilotView: View {
    private let useCases = MetaGlassesUseCase.all
    private let checklist = MetaGlassesPilotChecklistItem.all

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4).ignoresSafeArea()

            List {
                heroSection
                useCaseSection
                setupSection
                privacySection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Meta Glasses Pilot")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Label("Hands-free field capture", systemImage: "eyeglasses")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                Text("Meta's Wearables Device Access Toolkit can let Job Tracker prototype job-site workflows that use the glasses camera, microphones, and speakers while keeping the phone app as the control center.")
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)

                Text("Best first experiment: capture point-of-view photos or short video during splice, install, and damage-documentation steps, then attach the media to the active job.")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textMuted)
                    .padding(.top, JTSpacing.xs)
            }
            .padding(.vertical, JTSpacing.sm)
        }
        .listRowBackground(JTColors.glassHighlight)
    }

    private var useCaseSection: some View {
        Section("Useful Job Tracker pilots") {
            ForEach(useCases) { useCase in
                MetaGlassesUseCaseRow(useCase: useCase)
            }
        }
    }

    private var setupSection: some View {
        Section("Integration checklist") {
            ForEach(checklist) { item in
                HStack(alignment: .top, spacing: JTSpacing.sm) {
                    Image(systemName: item.systemImage)
                        .foregroundStyle(item.tint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: JTSpacing.xs) {
                        Text(item.title)
                            .font(JTTypography.subheadline.weight(.semibold))
                            .foregroundStyle(JTColors.textPrimary)
                        Text(item.detail)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                }
                .padding(.vertical, JTSpacing.xs)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy and rollout notes") {
            Label("Require explicit opt-in before camera, microphone, or speaker access.", systemImage: "hand.raised")
            Label("Start behind an internal pilot flag until your Meta developer project, bundle ID, release channel, and field policy are approved.", systemImage: "checklist")
            Label("Offer a clear analytics choice in Info.plist before enabling the SDK for testers.", systemImage: "chart.bar.doc.horizontal")
        }
        .font(JTTypography.caption)
        .foregroundStyle(JTColors.textSecondary)
    }
}

private struct MetaGlassesUseCaseRow: View {
    let useCase: MetaGlassesUseCase

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label(useCase.title, systemImage: useCase.systemImage)
                    .font(JTTypography.subheadline.weight(.semibold))
                    .foregroundStyle(JTColors.textPrimary)
                Spacer()
                Text(useCase.priority)
                    .font(JTTypography.caption.weight(.semibold))
                    .foregroundStyle(useCase.tint)
            }

            Text(useCase.detail)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)
        }
        .padding(.vertical, JTSpacing.xs)
    }
}

private struct MetaGlassesUseCase: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let priority: String
    let tint: Color

    static let all: [MetaGlassesUseCase] = [
        MetaGlassesUseCase(
            title: "Job photo capture",
            detail: "Attach hands-free POV photos to the current job for before/after proof, pole tags, splice trays, and damage evidence.",
            systemImage: "camera.viewfinder",
            priority: "High",
            tint: JTColors.success
        ),
        MetaGlassesUseCase(
            title: "Live splice assistance",
            detail: "Feed the glasses view into Splice Assist so a tech can ask for fiber identification, safety reminders, or next-step guidance without picking up the phone.",
            systemImage: "wand.and.stars.inverse",
            priority: "High",
            tint: JTColors.success
        ),
        MetaGlassesUseCase(
            title: "Voice notes for timesheets",
            detail: "Record quick completion notes, material usage, blockers, or arrival/departure context through the glasses microphones.",
            systemImage: "waveform",
            priority: "Medium",
            tint: JTColors.warning
        ),
        MetaGlassesUseCase(
            title: "Audio job prompts",
            detail: "Play turn-by-turn job prompts, safety checklists, or assignment updates through the glasses speakers while the phone stays pocketed.",
            systemImage: "speaker.wave.2",
            priority: "Medium",
            tint: JTColors.warning
        )
    ]
}

private struct MetaGlassesPilotChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    static let all: [MetaGlassesPilotChecklistItem] = [
        MetaGlassesPilotChecklistItem(
            title: "Add the Swift package",
            detail: "Use Xcode Swift Package Manager with https://github.com/facebook/meta-wearables-dat-ios, then add the product to the Job Tracker app target.",
            systemImage: "shippingbox",
            tint: JTColors.accent
        ),
        MetaGlassesPilotChecklistItem(
            title: "Register the app",
            detail: "Create a Wearables Developer Center project, register this bundle ID, and configure a release channel for internal testers.",
            systemImage: "person.badge.key",
            tint: JTColors.accent
        ),
        MetaGlassesPilotChecklistItem(
            title: "Prototype a media bridge",
            detail: "Wrap the SDK behind a service that exposes registration state, camera streaming, photo capture, and audio routing to SwiftUI.",
            systemImage: "arrow.left.arrow.right",
            tint: JTColors.accent
        ),
        MetaGlassesPilotChecklistItem(
            title: "Persist job attachments",
            detail: "Save captured media with the active job ID so Firebase Storage and job history can reuse the existing photo workflow.",
            systemImage: "folder.badge.plus",
            tint: JTColors.accent
        )
    ]
}

#Preview {
    NavigationStack {
        MetaGlassesPilotView()
    }
}

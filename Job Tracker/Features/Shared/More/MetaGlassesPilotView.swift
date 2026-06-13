import SwiftUI

struct MetaGlassesPilotView: View {
    @State private var selectedWorkflow: MetaGlassesWorkflow = .jobPhotoCapture
    @State private var isGlassesConnected = false
    @State private var isJobLinked = true
    @State private var isConsentConfirmed = false

    private let benefits = MetaGlassesBenefit.all
    private let workflows = MetaGlassesWorkflow.allCases
    private let checklist = MetaGlassesPilotChecklistItem.all

    private var pilotReadiness: Double {
        let completed = [isGlassesConnected, isJobLinked, isConsentConfirmed].filter { $0 }.count
        return Double(completed) / 3.0
    }

    private var readinessLabel: String {
        if pilotReadiness == 1.0 {
            return "Ready for a controlled field pilot"
        }
        if pilotReadiness >= 2.0 / 3.0 {
            return "Almost ready"
        }
        if pilotReadiness >= 1.0 / 3.0 {
            return "Needs setup"
        }
        return "Start with policy and device setup"
    }

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4).ignoresSafeArea()

            List {
                heroSection
                benefitSection
                workflowSection
                readinessSection
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

    private var benefitSection: some View {
        Section("How this helps technicians") {
            ForEach(benefits) { benefit in
                MetaGlassesBenefitRow(benefit: benefit)
            }
        }
    }

    private var workflowSection: some View {
        Section("Prototype workflow") {
            Picker("Workflow", selection: $selectedWorkflow) {
                ForEach(workflows) { workflow in
                    Label(workflow.title, systemImage: workflow.systemImage)
                        .tag(workflow)
                }
            }
            .pickerStyle(.menu)

            MetaGlassesWorkflowCard(workflow: selectedWorkflow)
        }
    }

    private var readinessSection: some View {
        Section("Pilot readiness") {
            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                HStack {
                    Text(readinessLabel)
                        .font(JTTypography.subheadline.weight(.semibold))
                        .foregroundStyle(JTColors.textPrimary)
                    Spacer()
                    Text(pilotReadiness, format: .percent.precision(.fractionLength(0)))
                        .font(JTTypography.caption.weight(.bold))
                        .foregroundStyle(readinessTint)
                }

                ProgressView(value: pilotReadiness)
                    .tint(readinessTint)
            }
            .padding(.vertical, JTSpacing.xs)

            Toggle("Glasses paired with the tester's phone", isOn: $isGlassesConnected)
            Toggle("Active job selected in Job Tracker", isOn: $isJobLinked)
            Toggle("Camera and microphone consent confirmed", isOn: $isConsentConfirmed)
        }
        .font(JTTypography.caption)
        .foregroundStyle(JTColors.textSecondary)
    }

    private var readinessTint: Color {
        if pilotReadiness == 1.0 { return JTColors.success }
        if pilotReadiness >= 2.0 / 3.0 { return JTColors.warning }
        return JTColors.accent
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

private struct MetaGlassesBenefitRow: View {
    let benefit: MetaGlassesBenefit

    var body: some View {
        HStack(alignment: .top, spacing: JTSpacing.sm) {
            Image(systemName: benefit.systemImage)
                .foregroundStyle(benefit.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: JTSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(benefit.title)
                        .font(JTTypography.subheadline.weight(.semibold))
                        .foregroundStyle(JTColors.textPrimary)
                    Spacer()
                    Text(benefit.impact)
                        .font(JTTypography.caption.weight(.semibold))
                        .foregroundStyle(benefit.tint)
                }

                Text(benefit.detail)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }
        }
        .padding(.vertical, JTSpacing.xs)
    }
}

private struct MetaGlassesWorkflowCard: View {
    let workflow: MetaGlassesWorkflow

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            Label(workflow.title, systemImage: workflow.systemImage)
                .font(JTTypography.subheadline.weight(.semibold))
                .foregroundStyle(JTColors.textPrimary)

            Text(workflow.userBenefit)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)

            Divider()

            ForEach(workflow.steps, id: \.self) { step in
                Label(step, systemImage: "checkmark.circle")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }
        }
        .padding(.vertical, JTSpacing.xs)
    }
}

private struct MetaGlassesBenefit: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let impact: String
    let tint: Color

    static let all: [MetaGlassesBenefit] = [
        MetaGlassesBenefit(
            title: "Less phone handling",
            detail: "Technicians can keep gloves on and continue working while documenting pole tags, splice trays, and job progress.",
            systemImage: "hand.tap",
            impact: "High",
            tint: JTColors.success
        ),
        MetaGlassesBenefit(
            title: "Cleaner job records",
            detail: "POV media can be attached to the active job immediately, reducing missing before/after photos and end-of-day admin cleanup.",
            systemImage: "folder.badge.plus",
            impact: "High",
            tint: JTColors.success
        ),
        MetaGlassesBenefit(
            title: "Faster assist requests",
            detail: "A captured view can become the input for Splice Assist or a supervisor review without asking the technician to stop and re-frame the scene on a phone.",
            systemImage: "person.wave.2",
            impact: "Medium",
            tint: JTColors.warning
        ),
        MetaGlassesBenefit(
            title: "Safer audio prompts",
            detail: "Route summaries, checklist reminders, and assignment updates can be played through glasses speakers so the phone stays pocketed.",
            systemImage: "speaker.wave.2",
            impact: "Medium",
            tint: JTColors.warning
        )
    ]
}

private enum MetaGlassesWorkflow: String, CaseIterable, Identifiable {
    case jobPhotoCapture
    case spliceAssist
    case voiceTimesheet
    case audioPrompts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jobPhotoCapture: return "Job photo capture"
        case .spliceAssist: return "Live Splice Assist"
        case .voiceTimesheet: return "Voice timesheet notes"
        case .audioPrompts: return "Audio job prompts"
        }
    }

    var systemImage: String {
        switch self {
        case .jobPhotoCapture: return "camera.viewfinder"
        case .spliceAssist: return "wand.and.stars.inverse"
        case .voiceTimesheet: return "waveform"
        case .audioPrompts: return "speaker.wave.2"
        }
    }

    var userBenefit: String {
        switch self {
        case .jobPhotoCapture:
            return "Capture proof while the work is happening and save it against the current job before the technician leaves the site."
        case .spliceAssist:
            return "Use the glasses view as context for fiber identification, troubleshooting, and supervisor escalation."
        case .voiceTimesheet:
            return "Dictate materials, blockers, and completion notes in the moment so the weekly timesheet is easier to finish."
        case .audioPrompts:
            return "Hear next steps, safety reminders, and route changes without unlocking the phone."
        }
    }

    var steps: [String] {
        switch self {
        case .jobPhotoCapture:
            return ["Confirm the active job", "Capture POV photo or clip", "Attach media to job history"]
        case .spliceAssist:
            return ["Stream or capture the splice view", "Send the image to Splice Assist", "Show or read back the recommended next step"]
        case .voiceTimesheet:
            return ["Record short field note", "Transcribe and tag it to the job", "Offer it during timesheet review"]
        case .audioPrompts:
            return ["Detect next job or checklist step", "Prepare concise audio prompt", "Play through glasses speakers"]
        }
    }
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

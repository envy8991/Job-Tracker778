import SwiftUI
import FirebaseFirestore

struct JobImportPreviewView: View {
    let preview: SharedJobPreview
    var onImportCompleted: () -> Void
    var onCancel: () -> Void

    @State private var isImporting = false
    @State private var localErrorMessage: String?

    private var payload: SharedJobPayload { preview.payload }
    private var scheduledDateText: String {
        JobImportPreviewView.dateFormatter.string(from: payload.date.dateValue())
    }
    private var jobNumberText: String {
        guard let jobNumber = payload.jobNumber, !jobNumber.isEmpty else { return "Not provided" }
        return jobNumber
    }

    private var sharedByText: String? {
        payload.senderDisplayName
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: JTSpacing.xxl) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: JTSpacing.xl) {
                            Text("Review shared job")
                                .font(JTTypography.title3)
                                .foregroundStyle(JTColors.textPrimary)

                            Text("Make sure the details look correct before adding it to your dashboard.")
                                .font(JTTypography.body)
                                .foregroundStyle(JTColors.textSecondary)

                            GlassCard {
                                VStack(alignment: .leading, spacing: JTSpacing.lg) {
                                    if let sharedByText {
                                        detailRow(title: "Shared by", value: sharedByText)
                                        Divider().overlay(JTColors.glassStroke)
                                    }
                                    detailRow(title: "Address", value: payload.address)
                                    Divider().overlay(JTColors.glassStroke)
                                    detailRow(title: "Scheduled date", value: scheduledDateText)
                                    Divider().overlay(JTColors.glassStroke)
                                    detailRow(title: "Status", value: payload.status)
                                    Divider().overlay(JTColors.glassStroke)
                                    detailRow(title: "Job number", value: jobNumberText)
                                    if let assignment = payload.assignment, !assignment.isEmpty {
                                        Divider().overlay(JTColors.glassStroke)
                                        detailRow(title: "Assignment", value: assignment)
                                    }
                                }
                                .padding(JTSpacing.xl)
                            }
                        }
                        .padding(.horizontal, JTSpacing.xl)
                        .padding(.top, JTSpacing.xl)
                    }

                    if let localErrorMessage {
                        Text(localErrorMessage)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, JTSpacing.xl)
                    }

                    VStack(spacing: JTSpacing.md) {
                        JTPrimaryButton(isImporting ? "Adding…" : "Add to my dashboard", systemImage: "tray.and.arrow.down.fill") {
                            handleImport()
                        }
                        .disabled(isImporting)

                        Button(role: .cancel) {
                            guard !isImporting else { return }
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .font(JTTypography.button)
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.bordered)
                        .tint(JTColors.textPrimary)
                        .disabled(isImporting)
                    }
                    .padding(.horizontal, JTSpacing.xl)
                    .padding(.bottom, JTSpacing.xl)
                }
                .navigationTitle("Import Job")
                .navigationBarTitleDisplayMode(.inline)
                .jtNavigationBarStyle()
                .interactiveDismissDisabled(isImporting)

                if isImporting {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        ProgressView("Importing…")
                            .font(JTTypography.body)
                            .padding(JTSpacing.xl)
                            .background(
                                .ultraThinMaterial,
                                in: JTShapes.roundedRectangle(cornerRadius: JTShapes.cardCornerRadius)
                            )
                    }
                }
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            Text(title.uppercased())
                .font(JTTypography.captionEmphasized)
                .foregroundStyle(JTColors.textMuted)
            Text(value)
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleImport() {
        guard !isImporting else { return }
        Task {
            await MainActor.run {
                isImporting = true
                localErrorMessage = nil
            }

            do {
                try await SharedJobService.shared.importJob(using: preview.token)
                await MainActor.run {
                    NotificationCenter.default.post(name: .jobImportSucceeded, object: nil)
                    isImporting = false
                    onImportCompleted()
                }
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(name: .jobImportFailed, object: error)
                    localErrorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

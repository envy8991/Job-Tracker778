import SwiftUI
import UIKit
import CoreLocation

struct JobSearchDetailView: View {
    let job: Job
    let metadata: JobSearchViewModel.Result

    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw = "apple"

    @State private var isGeneratingShareLink = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var isAdding = false
    @State private var errorMessage: String? = nil
    @State private var alertState: AlertState?

    private struct AlertState: Identifiable {
        enum Kind {
            case share
            case add
        }

        let id = UUID()
        let kind: Kind
        let message: String

        var title: String {
            switch kind {
            case .share:
                return "Couldn't Share Job"
            case .add:
                return "Unable to add job"
            }
        }
    }

    private var assignedToText: String? {
        guard let assignedID = job.assignedTo,
              let user = usersViewModel.usersDict[assignedID] else { return nil }
        return "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var creatorText: String? {
        if let creator = metadata.creator {
            if let role = creator.role, !role.isEmpty {
                return "Added by \(creator.name) · \(role)"
            } else {
                return "Added by \(creator.name)"
            }
        }
        if let creatorID = job.createdBy, let user = usersViewModel.usersDict[creatorID] {
            return "Added by \(user.firstName) \(user.lastName)"
        }
        return nil
    }

    private var infoItems: [DetailInfoItem] {
        var items: [DetailInfoItem] = []

        if let assigned = assignedToText, !assigned.isEmpty {
            items.append(.init(title: "Assigned to", value: assigned, systemImage: "person.crop.circle"))
        }

        if let assignments = displayValue(job.assignments) {
            items.append(.init(title: "Assignment", value: assignments, systemImage: "list.number"))
        }

        if let nid = displayValue(job.nidFootage) {
            items.append(.init(title: "NID Footage", value: nid, systemImage: "ruler"))
        }

        if let can = displayValue(job.canFootage) {
            items.append(.init(title: "CAN Footage", value: can, systemImage: "ruler"))
        }

        if job.hours > 0 {
            items.append(.init(title: "Hours logged", value: String(format: "%.1f hours", job.hours), systemImage: "clock"))
        }

        return items
    }

    private var notesText: String? { displayValue(job.notes) }
    private var materialsText: String? { displayValue(job.materialsUsed) }

    var body: some View {
        ZStack(alignment: .top) {
            JTGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: JTSpacing.xl) {
                    summaryCard

                    if !infoItems.isEmpty {
                        DetailInfoCard(title: "Job information", items: infoItems)
                    }

                    if let materialsText {
                        DetailTextCard(title: "Materials", systemImage: "shippingbox", text: materialsText)
                    }

                    if let notesText {
                        DetailTextCard(title: "Notes", systemImage: "note.text", text: notesText)
                    }

                    if !job.photos.isEmpty {
                        PhotosSection(photos: job.photos)
                    }
                }
                .padding(.horizontal, JTSpacing.lg)
                .padding(.vertical, JTSpacing.xl)
            }
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: JTSpacing.sm) {
                JTPrimaryButton(isAdding ? "Adding…" : "Add to Dashboard", systemImage: "plus.circle") {
                    addToDashboard()
                }
                .disabled(isAdding)
            }
            .padding(.horizontal, JTSpacing.lg)
            .padding(.top, JTSpacing.md)
            .padding(.bottom, JTSpacing.lg)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil }) {
            if let url = shareURL {
                let subject = metadata.address.primary
                ActivityView(activityItems: [url], subject: "Job link for \(subject)")
            }
        }
        .alert(item: $alertState) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("OK")) {
                    if state.kind == .add {
                        errorMessage = nil
                    }
                    alertState = nil
                }
            )
        }
    }

    private var summaryCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack(alignment: .top, spacing: JTSpacing.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metadata.address.primary)
                            .font(JTTypography.title3)
                            .foregroundStyle(JTColors.textPrimary)
                            .lineLimit(3)

                        if let secondary = metadata.address.secondary {
                            Text(secondary)
                                .font(JTTypography.subheadline)
                                .foregroundStyle(JTColors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: JTSpacing.sm)
                    if let jobNumber = metadata.jobNumber {
                        Text("#\(jobNumber)")
                            .font(JTTypography.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                            .foregroundStyle(JTColors.textPrimary)
                    }
                }

                HStack(spacing: JTSpacing.sm) {
                    Text(job.status)
                        .font(JTTypography.caption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(statusColor(job.status).opacity(0.18), in: Capsule())
                        .foregroundStyle(statusColor(job.status))

                    Text(job.date, style: .date)
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                }

                if let creatorText {
                    Label(creatorText, systemImage: "person.crop.circle")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                }

                if !metadata.isOwnedByCurrentUser {
                    Label("Found via team search", systemImage: "person.2")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                }

                quickActions
            }
            .padding(JTSpacing.lg)
        }
    }

    private var quickActions: some View {
        HStack(spacing: JTSpacing.sm) {
            QuickActionButton(title: "Directions", systemImage: "map") {
                openInMaps(job: job)
            }

            QuickActionButton(title: "Share", systemImage: "square.and.arrow.up", isLoading: isGeneratingShareLink) {
                share(job: job)
            }
            .disabled(isGeneratingShareLink)
        }
    }

    private func openInMaps(job: Job) {
        guard let encoded = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        if suggestionProviderRaw == "google" {
            if let url = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving") {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success { return }
                    if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
                        UIApplication.shared.open(appleURL)
                    }
                }
                return
            }
        }
        if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
            UIApplication.shared.open(appleURL)
        }
    }

    private func share(job: Job) {
        guard !isGeneratingShareLink else { return }
        alertState = nil
        shareURL = nil
        isGeneratingShareLink = true

        Task {
            do {
                let url = try await SharedJobService.shared.publishShareLink(job: job)
                await MainActor.run {
                    shareURL = url
                    isGeneratingShareLink = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    let message = description.isEmpty ? "We couldn’t share the job right now. Please try again." : description
                    alertState = AlertState(kind: .share, message: message)
                    isGeneratingShareLink = false
                }
            }
        }
    }

    private func addToDashboard() {
        guard !isAdding else { return }

        isAdding = true
        errorMessage = nil
        alertState = nil

        let trimmedAddress = job.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedAddress: String
        if trimmedAddress.isEmpty {
            if let secondary = metadata.address.secondary, !secondary.isEmpty {
                combinedAddress = "\(metadata.address.primary), \(secondary)"
            } else {
                combinedAddress = metadata.address.primary
            }
        } else {
            combinedAddress = trimmedAddress
        }

        let normalizedJobNumber = displayValue(metadata.jobNumber) ?? displayValue(job.jobNumber)

        let finishCreation: (CLLocationCoordinate2D?) -> Void = { coordinate in
            let resolvedLatitude = coordinate?.latitude ?? job.latitude
            let resolvedLongitude = coordinate?.longitude ?? job.longitude

            let newJob = Job(
                address: combinedAddress,
                date: Date(),
                status: "Pending",
                createdBy: authViewModel.currentUser?.id,
                jobNumber: normalizedJobNumber,
                latitude: resolvedLatitude,
                longitude: resolvedLongitude
            )

            jobsViewModel.createJob(newJob) { success in
                isAdding = false
                if success {
                    dismiss()
                } else {
                    let message = "We couldn’t add the job to your dashboard. Please try again."
                    errorMessage = message
                    alertState = AlertState(kind: .add, message: message)
                }
            }
        }

        CLGeocoder().geocodeAddressString(combinedAddress) { placemarks, _ in
            let coordinate = placemarks?.first?.location?.coordinate
            DispatchQueue.main.async {
                finishCreation(coordinate)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("done") || lower.contains("complete") {
            return JTColors.success
        }
        if lower.contains("pending") {
            return JTColors.warning
        }
        if lower.contains("hold") || lower.contains("blocked") || lower.contains("issue") {
            return JTColors.error
        }
        if lower.contains("need") {
            return JTColors.info
        }
        return JTColors.accent
    }

    private func displayValue(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Helpers

private struct DetailInfoItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String
}

private struct DetailInfoCard: View {
    let title: String
    let items: [DetailInfoItem]

    var body: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Text(title)
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: JTSpacing.sm) {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(JTColors.textSecondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title.uppercased())
                                .font(JTTypography.caption)
                                .foregroundStyle(JTColors.textSecondary)
                            Text(item.value)
                                .font(JTTypography.body)
                                .foregroundStyle(JTColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if index < items.count - 1 {
                        Divider()
                            .overlay(JTColors.glassSoftStroke.opacity(0.5))
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
    }
}

private struct DetailTextCard: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Label(title, systemImage: systemImage)
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                Text(text)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(JTSpacing.lg)
        }
    }
}

private struct PhotosSection: View {
    let photos: [String]

    var body: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: JTSpacing.sm) {
                        ForEach(photos, id: \.self) { urlString in
                            PhotoThumbnail(urlString: urlString)
                        }
                    }
                    .padding(.vertical, JTSpacing.xs)
                }
            }
            .padding(JTSpacing.lg)
        }
    }
}

private struct PhotoThumbnail: View {
    let urlString: String

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(JTColors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            JTColors.error.opacity(0.15)
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(JTColors.error)
                        }
                    @unknown default:
                        Color.clear
                    }
                }
            } else {
                ZStack {
                    JTColors.glassSoftStroke.opacity(0.2)
                    Image(systemName: "photo")
                        .foregroundStyle(JTColors.textSecondary)
                }
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: JTSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(JTColors.textPrimary)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(JTTypography.caption)
            .foregroundStyle(JTColors.textPrimary)
            .padding(.vertical, JTSpacing.xs)
            .padding(.horizontal, JTSpacing.sm)
            .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
        }
        .buttonStyle(.plain)
    }
}

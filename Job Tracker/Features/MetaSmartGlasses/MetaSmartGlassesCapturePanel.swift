import SwiftUI
import UIKit

struct MetaSmartGlassesCapturePanel: View {
    let job: Job
    @Binding var selectedSlot: JobPhotoSlot
    let onPhotoCaptured: (JobPhotoSlot, UIImage) -> Void

    @ObservedObject private var service = MetaSmartGlassesService.shared
    @AppStorage(MetaSmartGlassesSettings.enabledKey) private var assistantEnabled = false
    @AppStorage(MetaSmartGlassesSettings.requireReviewKey) private var requireReviewBeforeUpload = true
    @State private var showFallbackPicker = false
    @State private var showSourceDialog = false
    @State private var selectedPhotoSource: UIImagePickerController.SourceType = .camera
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: assistantEnabled ? "eyeglasses" : "eyeglasses.slash")
                    .font(.title3)
                    .foregroundStyle(assistantEnabled ? JTColors.accent : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Meta Smart Glasses")
                        .font(.subheadline.weight(.semibold))
                    Text(service.connectionState.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(service.connectionState.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            Picker("Evidence Type", selection: $selectedSlot) {
                ForEach(JobPhotoSlot.allCases, id: \.self) { slot in
                    Text(slot.displayTitle).tag(slot)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button {
                    Task { await captureFromGlasses() }
                } label: {
                    Label("Capture from Glasses", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!assistantEnabled)

                Button {
                    showSourceDialog = true
                } label: {
                    Label("Use Phone", systemImage: "iphone")
                }
                .buttonStyle(.bordered)
            }

            Text(requireReviewBeforeUpload
                 ? "Current job: \(job.shortAddress). Captures are reviewed on this screen before Save queues the upload."
                 : "Current job: \(job.shortAddress). Captures queue for upload immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { service.refreshState() }
        .confirmationDialog("Capture Evidence", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Phone Photo") {
                    selectedPhotoSource = .camera
                    showFallbackPicker = true
                }
            }
            Button("Choose Existing Photo") {
                selectedPhotoSource = .photoLibrary
                showFallbackPicker = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this fallback until the Meta SDK package is present in this build.")
        }
        .sheet(isPresented: $showFallbackPicker) {
            ImagePicker(
                image: Binding(
                    get: { nil },
                    set: { newImage in
                        guard let newImage else { return }
                        handleCapturedImage(newImage)
                    }
                ),
                sourceType: selectedPhotoSource
            )
        }
    }

    private func handleCapturedImage(_ image: UIImage, source: String = "phone") {
        if requireReviewBeforeUpload {
            onPhotoCaptured(selectedSlot, image)
            statusMessage = "Queued \(selectedSlot.displayTitle.lowercased()) from \(source) for review."
        } else {
            JobPhotoUploadQueue.shared.enqueue([(slot: selectedSlot, image: image)], for: job.id)
            statusMessage = "Queued \(selectedSlot.displayTitle.lowercased()) from \(source) for upload."
        }
    }

    private func captureFromGlasses() async {
        do {
            let image = try await service.capturePhoto()
            handleCapturedImage(image, source: "Meta glasses")
        } catch {
            statusMessage = error.localizedDescription
            showSourceDialog = true
        }
    }
}

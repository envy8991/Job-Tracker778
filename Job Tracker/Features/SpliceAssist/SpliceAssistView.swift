import SwiftUI

struct SpliceAssistView: View {
    @StateObject private var viewModel = SpliceAssistViewModel()

    @State private var isImagePickerPresented = false
    @State private var isTroubleshootSheetPresented = false
    @State private var isT2TooltipPresented = false

    @State private var troubleshootIdentifier: String = ""
    @State private var troubleshootColor: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: JTSpacing.xl) {
                header
                stepOneCard
                stepTwoCard
                stepThreeCard

                if let message = viewModel.message {
                    messageCard(message)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onTapGesture { viewModel.clearMessage() }
                }

                if viewModel.isProcessing || viewModel.result != nil {
                    resultsCard
                }
            }
            .padding(.horizontal, JTSpacing.xl)
            .padding(.vertical, JTSpacing.xxl)
        }
        .background(JTGradients.background(stops: 4).ignoresSafeArea())
        .navigationTitle("Splice Assist")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isImagePickerPresented) {
            SpliceAssistImagePicker { image in
                viewModel.setMapImage(image)
            }
        }
        .sheet(isPresented: $isTroubleshootSheetPresented) {
            troubleshootSheet
        }
        .alert("T2 Splitter", isPresented: $isT2TooltipPresented, actions: {
            Button("Got it", role: .cancel) { }
        }, message: {
            Text("Enable this if the can contains a T2 splitter. The AI will use T2 fiber colors (5–8) for the mainline assignment instead of standard drop colors (1–4).")
        })
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            Text("AI Fiber Splicer Helper")
                .font(JTTypography.title)
                .foregroundStyle(JTColors.textPrimary)

            Text("Your field assistant for accurate splicing and rapid troubleshooting.")
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textSecondary)
        }
    }

    // MARK: - Step cards
    private var stepOneCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
            VStack(alignment: .leading, spacing: JTSpacing.lg) {
                stepHeader(number: 1, title: "Provide Map & Context")

                VStack(alignment: .leading, spacing: JTSpacing.md) {
                    Text("Upload Assignment / Map")
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)

                    mapPreview

                    Button(action: { isImagePickerPresented = true }) {
                        Label(viewModel.hasMapImage ? "Change Map" : "Choose Map", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(JTColors.accent)
                }

                Toggle(isOn: $viewModel.isT2SplitterPresent) {
                    HStack(spacing: JTSpacing.sm) {
                        Text("T2 Splitter Present?")
                            .font(JTTypography.headline)
                            .foregroundStyle(JTColors.textPrimary)

                        Button {
                            isT2TooltipPresented = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(JTColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("About T2 splitters")
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(JTSpacing.lg)
        }
    }

    private var stepTwoCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
            VStack(alignment: .leading, spacing: JTSpacing.lg) {
                stepHeader(number: 2, title: "Identify Your Target")

                JTTextField("Splice Can Identifier",
                             text: $viewModel.canIdentifier,
                             icon: "number")
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Text("If you don't have an assignment, use the Find Assignment button below.")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }
            .padding(JTSpacing.lg)
        }
    }

    private var stepThreeCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
            VStack(alignment: .leading, spacing: JTSpacing.lg) {
                stepHeader(number: 3, title: "Action Center")

                Text("Choose an action based on your current task.")
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)

                VStack(spacing: JTSpacing.md) {
                    HStack(spacing: JTSpacing.md) {
                        SpliceAssistActionButton(title: "Troubleshoot",
                                                  symbol: "exclamationmark.triangle.fill",
                                                  tint: .red,
                                                  isDisabled: !viewModel.hasMapImage) {
                            troubleshootIdentifier = viewModel.canIdentifier
                            troubleshootColor = ""
                            isTroubleshootSheetPresented = true
                        }
                    }

                    HStack(spacing: JTSpacing.md) {
                        SpliceAssistActionButton(title: "Find Assignment",
                                                  symbol: "magnifyingglass",
                                                  tint: .green,
                                                  isDisabled: !viewModel.hasMapImage) {
                            Task { await viewModel.performAssignmentSearch() }
                        }

                        SpliceAssistActionButton(title: "Analyze Splice",
                                                  symbol: "bolt.fill",
                                                  tint: .blue,
                                                  isDisabled: !viewModel.canRunAnalysis) {
                            Task { await viewModel.performAnalysis() }
                        }
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    // MARK: - Message & Results
    private func messageCard(_ message: SpliceAssistViewModel.Message) -> some View {
        HStack(alignment: .top, spacing: JTSpacing.md) {
            Image(systemName: message.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(message.kind == .success ? JTColors.success : JTColors.error)
                .font(.system(size: 24))

            Text(message.text)
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textPrimary)
        }
        .padding(JTSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JTShapes.cardCornerRadius)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: JTShapes.cardCornerRadius)
                        .stroke(message.kind == .success ? JTColors.success.opacity(0.6) : JTColors.error.opacity(0.6), lineWidth: 1.5)
                )
        )
    }

    private var resultsCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
            VStack(alignment: .leading, spacing: JTSpacing.lg) {
                HStack(spacing: JTSpacing.sm) {
                    Image(systemName: viewModel.result?.action.symbolName ?? "hourglass")
                    Text(viewModel.result?.action.title ?? "Working…")
                        .font(JTTypography.headline)
                }
                .foregroundStyle(JTColors.textPrimary)

                if viewModel.isProcessing {
                    HStack(spacing: JTSpacing.md) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("AI is analyzing…")
                            .font(JTTypography.body)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                } else if let result = viewModel.result {
                    ScrollView {
                        VStack(alignment: .leading, spacing: JTSpacing.md) {
                            if let attributed = try? AttributedString(
                                markdown: result.content,
                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                            ) {
                                Text(attributed)
                                    .font(JTTypography.body)
                                    .foregroundStyle(JTColors.textPrimary)
                            } else {
                                Text(result.content)
                                    .font(JTTypography.body)
                                    .foregroundStyle(JTColors.textPrimary)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    // MARK: - Subviews
    private func stepHeader(number: Int, title: String) -> some View {
        HStack(alignment: .center, spacing: JTSpacing.md) {
            Text("\(number)")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 42, height: 42)
                .background(JTColors.accent, in: Circle())
                .foregroundStyle(JTColors.onAccent)

            Text(title)
                .font(JTTypography.headline)
                .foregroundStyle(JTColors.textPrimary)
        }
    }

    private var mapPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: JTShapes.cardCornerRadius)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(JTColors.glassStroke)
                .frame(maxWidth: .infinity)
                .frame(height: 220)

            if let image = viewModel.mapImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: JTShapes.cardCornerRadius))
            } else {
                Text("Upload map to begin…")
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
            }
        }
    }

    private var troubleshootSheet: some View {
        NavigationStack {
            Form {
                Section("Current Setup") {
                    TextField("Current can identifier", text: $troubleshootIdentifier)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("Missing fiber color", text: $troubleshootColor)
                        .autocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Troubleshoot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isTroubleshootSheetPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") {
                        isTroubleshootSheetPresented = false
                        Task {
                            await viewModel.performTroubleshoot(currentCan: troubleshootIdentifier, missingColor: troubleshootColor)
                        }
                    }
                    .disabled(troubleshootIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              troubleshootColor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct SpliceAssistActionButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let isDisabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: JTSpacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .bold))
                Text(title)
                    .font(JTTypography.subheadline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(JTColors.onAccent)
            .padding(.vertical, JTSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.95), tint.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: JTShapes.cardCornerRadius)
            )
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.4 : 1)
        .disabled(isDisabled)
    }
}

#Preview {
    NavigationStack {
        SpliceAssistView()
            .environmentObject(AppNavigationViewModel())
    }
}

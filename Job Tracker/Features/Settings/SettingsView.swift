import SwiftUI

// MARK: - iOS 26-Style Settings

// Lightweight section header label used inside cards
private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SettingsView: View {
    // MARK: - Dependencies
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject private var themeManager: JTThemeManager

    // Persisted settings
    @AppStorage("smartRoutingEnabled") private var smartRoutingEnabled = false
    @AppStorage("routingOptimizeBy")   private var optimizeByRaw      = "closest" // or "farthest"
    @AppStorage("arrivalAlertsEnabledToday") private var arrivalAlertsEnabledToday = true
    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw = "apple" // "apple" or "google"

    private enum OptimizeBy: String, CaseIterable, Identifiable {
        case closest, farthest
        var id: Self { self }
        var label: String { self == .closest ? "Closest-First" : "Farthest-First" }
    }

    // MARK: - UI State
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    @State private var showThemeEditor = false

    // Update these to your real URLs/emails
    private let privacyURL = URL(string: "https://gist.github.com/Qathom89911/82366354d14a9283d9d1c49f601c8f93")!
    private let supportMail = URL(string: "mailto:qathom8991@gmail.com")!

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {

                    // Title / Header
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.2.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(JTColors.textPrimary, JTColors.textSecondary)
                            .font(.system(size: 26, weight: .semibold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Settings")
                                .font(.system(.title2, weight: .bold))
                                .foregroundStyle(JTColors.textPrimary)
                            Text("Tune routing, notifications, and your account")
                                .font(.footnote)
                                .foregroundStyle(JTColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28) // room for the hamburger overlay (iOS 16-safe)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Appearance")
                            ThemeSelectionSection(showThemeEditor: $showThemeEditor)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Smart Routing
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Smart Routing")
                            Toggle("Enable Smart Routing", isOn: $smartRoutingEnabled)
                                .toggleStyle(.switch)
                                .accessibilityHint("Use your current job list to optimize stop order.")
                            if smartRoutingEnabled {
                                Picker("Optimize By", selection: $optimizeByRaw) {
                                    ForEach(OptimizeBy.allCases) { option in
                                        Text(option.label).tag(option.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityHint("Closest-first or farthest-first.")
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Notifications
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Notifications")
                            Toggle("Notify me on arrival (today only)", isOn: $arrivalAlertsEnabledToday)
                                .toggleStyle(.switch)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Maps & Addresses
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Maps & Addresses")

                            Picker("Address Suggestions", selection: $suggestionProviderRaw) {
                                Text("Apple (Default)").tag("apple")
                                Text("Google (Beta)").tag("google")
                            }
                            .pickerStyle(.segmented)

                            Text(
                                suggestionProviderRaw == "google"
                                ? "Using Google for address lookups. You can change this anytime here."
                                : "Using Apple Maps suggestions. You can change this anytime here."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .accessibilityLabel(
                                suggestionProviderRaw == "google"
                                ? "Using Google for address lookups."
                                : "Using Apple Maps for address suggestions."
                            )
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Account
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Account")

                            if let user = authViewModel.currentUser {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(user.firstName) \(user.lastName)")
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                            } else {
                                Text("Not signed in")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Button {
                                    authViewModel.signOut()
                                } label: {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                        .font(.callout.weight(.semibold))
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {
                                    Group {
                                        if isDeleting {
                                            ProgressView()
                                        } else {
                                            Label("Delete Account", systemImage: "trash")
                                        }
                                    }
                                    .font(.callout.weight(.semibold))
                                }
                                .disabled(isDeleting)
                            }
                            .alert("Delete your account?", isPresented: $showDeleteConfirm) {
                                Button("Delete", role: .destructive) {
                                    isDeleting = true
                                    deleteError = nil
                                    authViewModel.deleteAccount { result in
                                        isDeleting = false
                                        switch result {
                                        case .success:
                                            break
                                        case .failure(let err):
                                            deleteError = err.localizedDescription
                                        }
                                    }
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("This permanently deletes your account and removes your data from this app. Completed records required for bookkeeping may be retained in anonymized form as allowed by law.")
                            }

                            if let deleteError = deleteError {
                                Text(deleteError)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // Privacy & Support
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Privacy & Support")
                            Link(destination: privacyURL) {
                                Label("Privacy Policy", systemImage: "hand.raised")
                            }
                            .font(.callout.weight(.semibold))

                            Link(destination: supportMail) {
                                Label("Contact Support", systemImage: "envelope")
                            }
                            .font(.callout.weight(.semibold))
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // About
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "About")
                            HStack {
                                Text("Version")
                                Spacer()
                                Text(Bundle.main.appVersionReadable)
                                    .foregroundColor(.secondary)
                                    .accessibilityLabel("App version \(Bundle.main.appVersionReadable)")
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 16)

                    // bottom spacing for Home indicator
                    Color.clear.frame(height: 24)
                }
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showThemeEditor) {
            let storedCustom = themeManager.storedCustomTheme()
            ThemeEditorSheet(
                initialTheme: storedCustom ?? themeManager.theme,
                isEditingExistingCustom: storedCustom != nil,
                isPresented: $showThemeEditor
            )
            .environmentObject(themeManager)
        }
    }
}

private struct ThemeSelectionSection: View {
    @EnvironmentObject private var themeManager: JTThemeManager
    @Binding var showThemeEditor: Bool

    private var customPreview: JTTheme {
        if let stored = themeManager.storedCustomTheme() {
            return stored
        }
        let base = themeManager.theme
        return JTTheme(
            id: "custom-preview",
            name: "Custom",
            subtitle: "Start from your current palette",
            style: base.style,
            backgroundTop: base.backgroundTopColor,
            backgroundBottom: base.backgroundBottomColor,
            accent: base.accentColor
        )
    }

    private var statusDescription: String {
        if themeManager.isUsingCustomTheme {
            return "Custom theme active: \(themeManager.theme.name)"
        } else if let preset = themeManager.selectedPreset {
            return "Preset in use: \(preset.theme.name)"
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(themeManager.availablePresets) { preset in
                        ThemePreviewCard(
                            theme: preset.theme,
                            subtitle: preset.theme.subtitle,
                            isSelected: themeManager.selectedPreset == preset,
                            action: { themeManager.applyPreset(preset) }
                        )
                    }

                    ThemePreviewCard(
                        theme: customPreview,
                        subtitle: themeManager.storedCustomTheme() == nil ? "Tap to design" : "Your colors",
                        isSelected: themeManager.isUsingCustomTheme,
                        action: { showThemeEditor = true }
                    )
                }
                .padding(.vertical, 4)
            }

            Button {
                showThemeEditor = true
            } label: {
                Label(themeManager.isUsingCustomTheme ? "Edit custom theme" : "Create custom theme", systemImage: "paintbrush.pointed")
                    .font(.callout.weight(.semibold))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(JTColors.accent.opacity(0.18), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(JTColors.accent)

            if !statusDescription.isEmpty {
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(JTColors.textMuted)
            }
        }
    }
}

private struct ThemePreviewCard: View {
    let theme: JTTheme
    let subtitle: String?
    let isSelected: Bool
    var action: () -> Void

    private var outlineColor: Color {
        isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.4)
    }

    private var textColor: Color { Color.white }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: theme.backgroundGradientStops(count: 4),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(outlineColor, lineWidth: isSelected ? 3 : 1.5)
                    )
                    .overlay(alignment: .topLeading) {
                        Capsule(style: .continuous)
                            .fill(theme.accentColor)
                            .frame(width: 36, height: 12)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(theme.onAccentColor.opacity(0.55), lineWidth: 1)
                            )
                            .padding(10)
                    }
                    .frame(width: 150, height: 90)

                Text(theme.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(width: 170, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? JTColors.accent : JTColors.glassStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeEditorSheet: View {
    @EnvironmentObject private var themeManager: JTThemeManager
    private let originalTheme: JTTheme
    private let isEditingExistingCustom: Bool
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var backgroundTop: Color
    @State private var backgroundBottom: Color
    @State private var accent: Color

    init(initialTheme: JTTheme, isEditingExistingCustom: Bool, isPresented: Binding<Bool>) {
        self.originalTheme = initialTheme
        self.isEditingExistingCustom = isEditingExistingCustom
        _name = State(initialValue: initialTheme.name)
        _backgroundTop = State(initialValue: initialTheme.backgroundTopColor)
        _backgroundBottom = State(initialValue: initialTheme.backgroundBottomColor)
        _accent = State(initialValue: initialTheme.accentColor)
        _isPresented = isPresented
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Theme name", text: $name)
                }

                Section("Background") {
                    ColorPicker("Top", selection: $backgroundTop, supportsOpacity: false)
                    ColorPicker("Bottom", selection: $backgroundBottom, supportsOpacity: false)
                }

                Section("Accent") {
                    ColorPicker("Accent", selection: $accent, supportsOpacity: false)
                }

                Section("Preview") {
                    ThemePreviewDisplay(theme: previewTheme)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .navigationTitle("Custom Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmed.isEmpty ? "Custom" : trimmed
                        let customID = isEditingExistingCustom ? originalTheme.id : "custom-\(UUID().uuidString)"
                        let customTheme = JTTheme(
                            id: customID,
                            name: finalName,
                            subtitle: "User defined",
                            style: originalTheme.style,
                            backgroundTop: backgroundTop,
                            backgroundBottom: backgroundBottom,
                            accent: accent
                        )
                        themeManager.applyCustom(customTheme)
                        isPresented = false
                    }
                }
            }
        }
    }

    private var previewTheme: JTTheme {
        let previewID = isEditingExistingCustom ? originalTheme.id : "preview"
        return JTTheme(
            id: previewID,
            name: name,
            subtitle: originalTheme.subtitle,
            style: originalTheme.style,
            backgroundTop: backgroundTop,
            backgroundBottom: backgroundBottom,
            accent: accent
        )
    }
}

private struct ThemePreviewDisplay: View {
    let theme: JTTheme

    private var textColor: Color { Color.white }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: theme.backgroundGradientStops(count: 4),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(textColor.opacity(0.25), lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.name.isEmpty ? "Preview" : theme.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(textColor)
                    if let subtitle = theme.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.8))
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)

            HStack(spacing: 16) {
                Capsule()
                    .fill(theme.accentColor)
                    .frame(height: 36)
                    .overlay(
                        Text("Accent sample")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.onAccentColor)
                    )

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 36)
                    .overlay(
                        Text("Glass surface")
                            .font(.footnote)
                            .foregroundColor(textColor.opacity(0.85))
                    )
            }
        }
    }
}

// MARK: - Version helper
private extension Bundle {
    var appVersionReadable: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

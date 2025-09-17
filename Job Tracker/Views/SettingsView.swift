import SwiftUI

// MARK: - iOS 26-Style Settings

// Background gradient (kept from your original but renamed for clarity)
private let settingsGradient = LinearGradient(
    gradient: Gradient(colors: [
        Color(red: 0.1725, green: 0.2431, blue: 0.3137), // deep steel
        Color(red: 0.2980, green: 0.6314, blue: 0.6863)  // teal mist
    ]),
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// A reusable frosted "glass" container that matches the iOS-26 vibe used elsewhere.
// Pure SwiftUI (iOS 16+) — no external helpers required.
private struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)
    }
}

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

    // Update these to your real URLs/emails
    private let privacyURL = URL(string: "https://gist.github.com/Qathom89911/82366354d14a9283d9d1c49f601c8f93")!
    private let supportMail = URL(string: "mailto:qathom8991@gmail.com")!

    var body: some View {
        ZStack {
            // glassy gradient background
            settingsGradient
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {

                    // Title / Header
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.2.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white.opacity(0.95), .white.opacity(0.45))
                            .font(.system(size: 26, weight: .semibold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Settings")
                                .font(.system(.title2, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))
                            Text("Tune routing, notifications, and your account")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28) // room for the hamburger overlay (iOS 16-safe)

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
                    }
                    .padding(.horizontal, 16)

                    // Notifications
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Notifications")
                            Toggle("Notify me on arrival (today only)", isOn: $arrivalAlertsEnabledToday)
                                .toggleStyle(.switch)
                        }
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
        .hamburgerClearance(72)
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

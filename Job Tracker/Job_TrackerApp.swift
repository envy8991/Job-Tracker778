//
//  JobTrackerApp.swift
//  Job Tracking Cable South
//
//  Created by Quinton Thompson on 2/8/25.
//  Updated on 3/22/25
//

import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit
import WatchConnectivity

@main
struct JobTrackerApp: App {
    // Ensure Firebase is configured before any view models are created
    private static func ensureFirebaseConfigured() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            // Enable Firestore offline persistence for robust offline support
            let db = Firestore.firestore()
            let settings = db.settings
            // Use the modern cache API (replaces deprecated `isPersistenceEnabled`)
            settings.cacheSettings = PersistentCacheSettings() // on-device persistent cache across launches
            db.settings = settings
        }
    }
    private static func makeAuthVM() -> AuthViewModel {
        ensureFirebaseConfigured(); return AuthViewModel()
    }
    private static func makeJobsVM() -> JobsViewModel {
        ensureFirebaseConfigured(); return JobsViewModel()
    }
    private static func makeUsersVM() -> UsersViewModel {
        ensureFirebaseConfigured(); return UsersViewModel()
    }
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Main view models for authentication and data
    @StateObject private var authViewModel  = JobTrackerApp.makeAuthVM()
    @StateObject private var jobsViewModel  = JobTrackerApp.makeJobsVM()
    @StateObject private var usersViewModel = JobTrackerApp.makeUsersVM()
    @StateObject private var navigationViewModel = AppNavigationViewModel()
    @StateObject private var themeManager = JTThemeManager.shared
    @AppStorage("arrivalAlertsEnabledToday") private var arrivalAlertsEnabledToday = true
    @State private var showSplash: Bool = true
    @State private var showImportSuccess: Bool = false
    @State private var importFailureMessage: String? = nil
    @State private var didWireWatchBridge = false
    @State private var pendingSharedJobPreview: SharedJobPreview?

    // Background/foreground location switching
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationService: LocationService
    @StateObject private var arrivalAlertManager: ArrivalAlertManager

    init() {
        let locationService = LocationService()
        _locationService = StateObject(wrappedValue: locationService)
        _arrivalAlertManager = StateObject(wrappedValue: ArrivalAlertManager(locationService: locationService))
    }
    
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    ContentView()
                        // Activate WCSession + push snapshot when main UI appears
                        .onAppear {
                            if !didWireWatchBridge {
                                PhoneWatchSyncManager.shared.configure(jobsViewModel: jobsViewModel)
                                didWireWatchBridge = true
                            }
                            // Start foreground location updates
                            locationService.startStandardUpdates()
                            // Ensure the watch has the latest on first appearance
                            PhoneWatchSyncManager.shared.pushSnapshotToWatch()
                            arrivalAlertManager.updateJobs(jobsViewModel.jobs)
                        }
                        .onReceive(jobsViewModel.$jobs) { jobs in
                            PhoneWatchSyncManager.shared.pushSnapshotToWatch()
                            arrivalAlertManager.updateJobs(jobs)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                            PhoneWatchSyncManager.shared.pushSnapshotToWatch()
                            arrivalAlertManager.updateJobs(jobsViewModel.jobs)
                        }
                }
                .opacity(showSplash ? 0 : 1)
                
                if showSplash {
                    AnimatedSplashView {
                        withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
                    }
                    .transition(.opacity)
                }
                
                // Import banners (shown after deep link handling)
                VStack(spacing: 8) {
                    if showImportSuccess {
                        BannerView(style: .success, text: "Job imported to your dashboard")
                    }
                    if let msg = importFailureMessage {
                        BannerView(style: .error, text: msg)
                    }
                    Spacer()
                }
                .padding(.top, 18)
                .opacity(showSplash ? 0 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showImportSuccess)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: importFailureMessage)
            }
            // Make view models available to the main content views
            .environmentObject(authViewModel)
            .environmentObject(jobsViewModel)
            .environmentObject(usersViewModel)
            .environmentObject(navigationViewModel)
            .environmentObject(locationService)
            .environmentObject(arrivalAlertManager)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.theme.colorScheme)
            .tint(themeManager.theme.accentColor)
            .sheet(item: $pendingSharedJobPreview) { preview in
                JobImportPreviewView(
                    preview: preview,
                    onImportCompleted: {
                        pendingSharedJobPreview = nil
                    },
                    onCancel: {
                        pendingSharedJobPreview = nil
                    }
                )
                .environmentObject(themeManager)
            }
            // Deep links
            .onOpenURL { url in
                JobTrackerApp.ensureFirebaseConfigured()
                guard let route = DeepLinkRouter.handle(url) else { return }

                switch route {
                case let .importJob(token):
                    Task {
                        await MainActor.run {
                            pendingSharedJobPreview = nil
                        }
                        do {
                            let preview = try await SharedJobService.shared.loadSharedJob(token: token)
                            await MainActor.run {
                                pendingSharedJobPreview = preview
                            }
                        } catch {
                            #if DEBUG
                            print("[DeepLink] Failed to load shared job: \(error.localizedDescription)")
                            #endif
                            await MainActor.run {
                                NotificationCenter.default.post(name: .jobImportFailed, object: error)
                            }
                        }
                    }
                }
            }
            // Import banners + watch sync
            .onReceive(NotificationCenter.default.publisher(for: .jobImportSucceeded)) { _ in
                withAnimation { showImportSuccess = true }
                PhoneWatchSyncManager.shared.pushSnapshotToWatch()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { showImportSuccess = false }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobImportFailed)) { note in
                let msg = (note.object as? Error)?.localizedDescription ?? "Import failed"
                withAnimation { importFailureMessage = msg }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation { importFailureMessage = nil }
                }
            }
            // Keep Watch snapshot in sync with any pending-write state changes
            .onReceive(NotificationCenter.default.publisher(for: .jobsSyncStateDidChange)) { _ in
                PhoneWatchSyncManager.shared.pushSnapshotToWatch()
            }
            // Switch location strategy based on lifecycle
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    locationService.startStandardUpdates()
                case .background:
                    locationService.startSignificantChangeUpdates()
                default:
                    break
                }
            }
        }
    }
    
    // (pushJobsSnapshotToWatch and PhoneWatchBridge removed)
    
    // MARK: - Lightweight Animated Splash (Route draw, polished, no spinning)
    private struct AnimatedSplashView: View {
        var onFinished: () -> Void
        
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        
        @State private var drawRoute = false
        @State private var showBrand = false
        @State private var fadeOut = false
        @State private var sweepX: CGFloat = -120
        @State private var progress: CGFloat = 0
        @State private var showPin1 = false
        @State private var showPin2 = false
        @State private var showPin3 = false
        private let f1: CGFloat = RouteShape.f1
        private let f2: CGFloat = RouteShape.f2
        
        private enum T { // timings
            static let segment: Double = 0.6
            static let revealDelay: Double = 0.35
            static let total: Double = 3.0
            static let fade: Double = 0.35
        }
        
        var body: some View {
            ZStack {
                // Calm gradient background that adapts to light/dark
                LinearGradient(
                    gradient: Gradient(colors: backgroundColors),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(
                    // Gentle vignette for depth (honor Reduce Transparency)
                    LinearGradient(
                        colors: reduceTransparency ? [.clear, .clear] : [
                            .black.opacity(0.0), .black.opacity(0.15)
                        ],
                        startPoint: .center, endPoint: .bottom
                    )
                )
                
                GeometryReader { geo in
                    // A horizontal route centered under the logo
                    let w = min(geo.size.width * 0.74, 360)
                    let h: CGFloat = 44
                    let ox = (geo.size.width  - w) / 2
                    let oy = (geo.size.height - h) / 2 + 130 // push below centered logo
                    
                    let p1Rel = RouteShape.pin1Rel
                    let p2Rel = RouteShape.pin2Rel
                    let p3Rel = RouteShape.pin3Rel
                    
                    let p1 = CGPoint(x: ox + w * p1Rel.x, y: oy + h * p1Rel.y)
                    let p2 = CGPoint(x: ox + w * p2Rel.x, y: oy + h * p2Rel.y)
                    let p3 = CGPoint(x: ox + w * p3Rel.x, y: oy + h * p3Rel.y)
                    
                    ZStack {
                        // Route line that draws progressively to 3 pins
                        RouteShape()
                            .trim(from: 0, to: max(0.0001, progress))
                            .stroke(
                                Color.white.opacity(0.95),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                            .frame(width: w, height: h)
                            .offset(x: ox, y: oy)
                            .animation(.easeOut(duration: T.segment), value: progress)
                        
                        // Pins appear as the route reaches them
                        Image(systemName: "mappin.circle.fill")
                            .resizable().scaledToFit().frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                            .scaleEffect(showPin1 ? 1.0 : 0.6)
                            .opacity(showPin1 ? 1.0 : 0.0)
                            .position(p1)
                        
                        Image(systemName: "mappin.circle.fill")
                            .resizable().scaledToFit().frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                            .scaleEffect(showPin2 ? 1.0 : 0.6)
                            .opacity(showPin2 ? 1.0 : 0.0)
                            .position(p2)
                        
                        Image(systemName: "mappin.circle.fill")
                            .resizable().scaledToFit().frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                            .scaleEffect(showPin3 ? 1.0 : 0.6)
                            .opacity(showPin3 ? 1.0 : 0.0)
                            .position(p3)
                    }
                    .drawingGroup()
                    .allowsHitTesting(false)
                }
                
                // Brand reveal with subtle shimmer on title
                VStack(spacing: 10) {
                    ZStack {
                        // Logo
                        Group {
                            if UIImage(named: "LaunchLogo") != nil {
                                Image("LaunchLogo").resizable().scaledToFit()
                            } else {
                                Image(systemName: "bolt.circle.fill").resizable().scaledToFit()
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        
                        // Highlight sweep (masked to the logo bounds)
                        if showBrand && !reduceTransparency {
                            LinearGradient(colors: [
                                .clear,
                                .white.opacity(0.85),
                                .clear
                            ], startPoint: .top, endPoint: .bottom)
                            .frame(width: 28, height: 130)
                            .rotationEffect(.degrees(24))
                            .offset(x: sweepX)
                            .blendMode(.screen)
                            .mask(
                                Group {
                                    if UIImage(named: "LaunchLogo") != nil {
                                        Image("LaunchLogo").resizable().scaledToFit()
                                    } else {
                                        Image(systemName: "bolt.circle.fill").resizable().scaledToFit()
                                    }
                                }
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    .scaleEffect(showBrand ? 1.0 : 0.88)
                    .opacity(showBrand ? 1.0 : 0.0)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: showBrand)
                    .accessibilityHidden(true)
                    
                    Text("Job Tracker")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                        .opacity(showBrand ? 1 : 0)
                        .offset(y: showBrand ? 0 : 8)
                        .animation(.easeOut(duration: 0.28).delay(0.05), value: showBrand)
                    
                    Text("Plan • Route • Report")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.white.opacity(0.85))
                        .opacity(showBrand ? 1 : 0)
                        .animation(.easeIn(duration: 0.25).delay(0.1), value: showBrand)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .opacity(fadeOut ? 0 : 1)
                .animation(.easeOut(duration: T.fade), value: fadeOut)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Launching Job Tracker")
            }
            .onAppear { startSequence() }
            .accessibilityAddTraits(.isHeader)
        }
        
        private var backgroundColors: [Color] {
            if colorScheme == .light {
                return [
                    Color(red: 0.92, green: 0.97, blue: 1.00),
                    Color(red: 0.70, green: 0.86, blue: 0.93)
                ]
            } else {
                return [
                    Color(red: 0.10, green: 0.14, blue: 0.18),
                    Color(red: 0.20, green: 0.45, blue: 0.55)
                ]
            }
        }
        
        private func startSequence() {
            if reduceMotion {
                progress = 1
                showBrand = true
                showPin1 = true; showPin2 = true; showPin3 = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { finish() }
                return
            }
            
            // Seed a tiny length so trim has something to render on first frame
            progress = 0.0001
            
            // 1) Brand reveal + highlight sweep
            DispatchQueue.main.asyncAfter(deadline: .now() + T.revealDelay) { showBrand = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + T.revealDelay + 0.10) {
                withAnimation(.easeInOut(duration: 0.9)) { sweepX = 120 }
            }
            
            // 2) Reveal first pin, then draw to pin 2, reveal pin 2, then draw to pin 3, reveal pin 3
            let start1 = T.revealDelay + 0.15
            
            // Pin 1 appears just before we start drawing
            DispatchQueue.main.asyncAfter(deadline: .now() + start1 - 0.10) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showPin1 = true }
            }
            
            // Segment 1 → Pin1 to Pin2
            DispatchQueue.main.asyncAfter(deadline: .now() + start1) {
                withAnimation(.easeOut(duration: T.segment)) { progress = f1 }
            }
            // Reveal Pin 2 right after the first segment completes
            DispatchQueue.main.asyncAfter(deadline: .now() + start1 + T.segment + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showPin2 = true }
            }
            
            // Segment 2 → Pin2 to Pin3
            DispatchQueue.main.asyncAfter(deadline: .now() + start1 + T.segment + 0.15) {
                withAnimation(.easeOut(duration: T.segment)) { progress = 1.0 }
            }
            // Reveal Pin 3 at the end
            DispatchQueue.main.asyncAfter(deadline: .now() + start1 + (2 * T.segment) + 0.20) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showPin3 = true }
            }
            
            // 3) Finish after the drawing completes (pad a bit for visual settling)
            let finishDelay = max(T.total, start1 + (2 * T.segment) + 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) { finish() }
        }
        
        private func finish() {
            guard !fadeOut else { return }
            fadeOut = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + T.fade) { onFinished() }
        }
    }
    
    /// Simple two‑segment route path used in the splash.
    private struct RouteShape: Shape {
        static let pin1Rel  = CGPoint(x: 0.20, y: 0.50)
        static let pin2Rel  = CGPoint(x: 0.50, y: 0.50)
        static let pin3Rel  = CGPoint(x: 0.80, y: 0.50)
        
        static var f1: CGFloat {
            let a = pin1Rel, b = pin2Rel, c = pin3Rel
            let l1 = CGFloat(hypot(b.x - a.x, b.y - a.y))
            let l2 = CGFloat(hypot(c.x - b.x, c.y - b.y))
            let total = max(l1 + l2, 0.0001)
            return l1 / total
        }
        
        static var f2: CGFloat {
            let a = pin1Rel, b = pin2Rel, c = pin3Rel
            let l1 = CGFloat(hypot(b.x - a.x, b.y - a.y))
            let l2 = CGFloat(hypot(c.x - b.x, c.y - b.y))
            let total = max(l1 + l2, 0.0001)
            return (l1 + l2) / total
        }
        
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let p1 = CGPoint(x: rect.minX + rect.width  * Self.pin1Rel.x,
                             y: rect.minY + rect.height * Self.pin1Rel.y)
            let p2 = CGPoint(x: rect.minX + rect.width  * Self.pin2Rel.x,
                             y: rect.minY + rect.height * Self.pin2Rel.y)
            let p3 = CGPoint(x: rect.minX + rect.width  * Self.pin3Rel.x,
                             y: rect.minY + rect.height * Self.pin3Rel.y)
            p.move(to: p1)
            p.addLine(to: p2)
            p.addLine(to: p3)
            return p
        }
    }
    
    // MARK: - Simple in-app banner (success / error)
    private struct BannerView: View {
        enum Style { case success, error }
        let style: Style
        let text: String
        
        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .imageScale(.medium)
                Text(text)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style == .success ? Color.green.opacity(0.90) : Color.red.opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
        }
    }
}

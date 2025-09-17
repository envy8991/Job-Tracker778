//
//  MainTabView.swift
//  Job Tracker
//
//  Updated  May 2025
//

import SwiftUI

private let kMenuWidth: CGFloat = 300
private let kHamburgerInsetHeight: CGFloat = 64 // reserves space below the floating hamburger

// MARK: – Drawer destinations
enum MenuDestination: CaseIterable {
    case profile
    case dashboard
    case timesheets
    case yellowSheets
    case maps
    case jobSearch
    case findPartner   // NEW
    case supervisor    // NEW
    case admin         // NEW
    case settings
    case helpCenter
}

// MARK: – Root container
struct MainTabView: View {
    
    // Drawer state
    @State private var showMenu = false
    @State private var selected: MenuDestination = .dashboard
    
    // Services
    @StateObject private var locationService  = LocationService()
   
    
    // Global view‑models provided higher in the hierarchy
    @EnvironmentObject var usersViewModel: UsersViewModel
    @EnvironmentObject var authViewModel:  AuthViewModel
    
    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            
            ZStack(alignment: .leading) {
                
                // ── Active screen ────────────────────────────────────────────────
                activeScreen
                    .disabled(showMenu)                     // lock touches when drawer open
                    .scaleEffect(showMenu ? 0.98 : 1.0)
                    .offset(x: showMenu ? kMenuWidth * 0.12 : 0)
                    .overlay(
                        Rectangle()
                            .fill(Color.black.opacity(showMenu ? 0.12 : 0))
                            .allowsHitTesting(false)
                    )
                    // Reserve headroom under the floating hamburger so it never obscures content.
                    .safeAreaInset(edge: .top) {
                        Color.clear
                            .frame(height: kHamburgerInsetHeight)
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.9), value: showMenu)
                
                // ── Hamburger button ────────────────────────────────────────────
                VStack {
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showMenu.toggle() }
                        } label: {
                            Image(systemName: "line.horizontal.3")
                                .imageScale(.large)
                                .padding(12)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .shadow(radius: 6, y: 3)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                // sit just below the status bar on all devices
                .padding(.top, topInset + 6)
                .padding(.leading, 16)
                .zIndex(showMenu ? 0 : 1)
                
                // ── Tap‑to‑dismiss overlay ──────────────────────────────────────
                if showMenu {
                    Color.black.opacity(0.001)             // invisible hit‑area
                        .ignoresSafeArea()
                        .padding(.leading, kMenuWidth)      // exclude drawer width
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showMenu = false }
                        }
                }
                
                // ── Slide‑in side menu ─────────────────────────────────────────
                SideMenuView(showMenu: $showMenu, selected: $selected)
                    .frame(width: kMenuWidth)
                    .offset(x: showMenu ? 0 : -kMenuWidth)
                    .accessibilityHidden(!showMenu)
                    .animation(.spring(response: 0.32, dampingFraction: 0.9), value: showMenu)
                    .zIndex(2) // ensure drawer sits above content and hamburger when open
                
                // Edge-swipe to open
                Color.clear
                    .frame(width: 16)
                    .contentShape(Rectangle())
                    .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                        // keep layout reactive on rotation; no-op but forces refresh
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.startLocation.x <= 16, value.translation.width > 24 {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showMenu = true }
                                }
                            }
                    )
                    .ignoresSafeArea(edges: .vertical)
                    .zIndex(1)
            }
            .zIndex(0)
        }
    }
    
    // MARK: – Screen switcher
    @ViewBuilder
    private var activeScreen: some View {
        switch selected {
        case .profile:
            ProfileView()
            
        case .dashboard:
            DashboardView()
                .environmentObject(locationService)
                
            
        case .timesheets:
            WeeklyTimesheetView()
            
        case .yellowSheets:
            YellowSheetView()
            
        case .maps:
            MapsView()
                .environmentObject(locationService)
                
            
        case .jobSearch:
            JobSearchView()
            
        case .findPartner:
            NavigationStack {
                FindPartnerView()
                    .environmentObject(usersViewModel)
                    .environmentObject(authViewModel)
            }
            
        case .supervisor:
            NavigationStack {
                SupervisorDashboardView()
                    .environmentObject(authViewModel)
            }

        case .admin:
            NavigationStack {
                AdminPanelView()
                    .environmentObject(authViewModel)
            }
            
        case .helpCenter:
            NavigationStack {
                HelpCenterView(onNavigate: { dest in
                    // Switch the selected tab when a Help topic's "Try it now" is tapped
                    selected = dest
                })
            }
            
        case .settings:
            SettingsView()
        }
    }
}

// MARK: – Side‑Menu drawer
struct SideMenuView: View {
    @Binding var showMenu: Bool
    @Binding var selected: MenuDestination
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Frosted glass background with subtle gradient tint
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 12)
                .ignoresSafeArea(edges: .bottom) // keep top insets so it never overlaps status elements
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Profile header ─────────────────────────────────────────────
                    Button {
                        selected = .profile
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showMenu = false }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 56, height: 56)
                                .foregroundStyle(.white)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authViewModel.currentUser.map { "\($0.firstName) \($0.lastName)" } ?? "Profile")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(authViewModel.currentUser?.email ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 52)
                        .padding(.bottom, 20)
                    }
                    .buttonStyle(.plain)
                    
                    // ── Menu sections ──────────────────────────────────────────────
                    sectionLabel("MAIN")
                    menuButton("Dashboard",  .dashboard, systemImage: "rectangle.grid.2x2")
                    
                    sectionLabel("INFO")
                    menuButton("Timesheets",    .timesheets, systemImage: "clock")
                    menuButton("Yellow Sheets", .yellowSheets, systemImage: "doc.text")
                    
                    sectionLabel("MAPS")
                    menuButton("Route Mapper", .maps, systemImage: "map")
                    
                    sectionLabel("JOB SEARCH")
                    menuButton("Job Search", .jobSearch, systemImage: "magnifyingglass")
                    
                    sectionLabel("CREW PARTNER")
                    menuButton("Find a Partner", .findPartner, systemImage: "person.2")
                    
                    if authViewModel.isSupervisorFlag {
                        sectionLabel("SUPERVISOR")
                        menuButton("Supervisor", .supervisor, systemImage: "person.text.rectangle")
                    }
                    
                    if authViewModel.isAdminFlag {
                        sectionLabel("ADMIN")
                        menuButton("Admin", .admin, systemImage: "gearshape.2")
                    }
                    
                    sectionLabel("HELP")
                    menuButton("Help Center", .helpCenter, systemImage: "questionmark.circle")
                    
                    sectionLabel("SETTINGS")
                    menuButton("Settings", .settings, systemImage: "gearshape")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24) // breathing room on small screens
            }
        }
    }
    
    // MARK: – Helpers
    private func menuButton(_ label: String, _ dest: MenuDestination, showDot: Bool = false, systemImage: String? = nil) -> some View {
        Button {
            selected = dest
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showMenu = false }
        } label: {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                        .frame(width: 20)
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if showDot {
                    Circle()
                        .fill(Color(red: 0.31, green: 0.97, blue: 0.66))
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(selected == dest ? 0.12 : 0.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(selected == dest ? 0.22 : 0.0), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal)
            .padding(.top, 20)
    }
}

// MARK: – Placeholder screens (replace with real implementations)

struct AdminPanelView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var body: some View {
        VStack(spacing: 12) {
            Text("Admin Panel")
                .font(.title2).bold()
            Text("Use this area to manage users, flags, and global settings.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Admin")
    }
}

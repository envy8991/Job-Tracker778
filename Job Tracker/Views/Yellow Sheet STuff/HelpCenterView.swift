//
//  HelpCenterView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 9/6/25.
//
import CoreLocation   // for distance / CLLocation
import SwiftUI
import UIKit // for UIImage in share attachments

// Local glass card style to avoid relying on fileprivate symbols from other files
private struct HelpGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}
private extension View {
    func helpGlassCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(HelpGlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: – Help Center
struct HelpCenterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var navigation: AppNavigationViewModel

    @State private var query: String = ""
    @State private var showingCreateJob = false
    @State fileprivate var selectedTopic: HelpTopic? = nil

    fileprivate struct HelpTopic: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let summary: String
        let bullets: [String]
        let action: (() -> Void)?      // optional “Try it now”
    }

    private var topics: [HelpTopic] {
        [
            HelpTopic(
                title: "Quick Start",
                icon: "bolt.circle.fill",
                summary: "Create a job, update its status, and share or print.",
                bullets: [
                    "Tap **Create Job** to add Job #, address, assignments, photos, and notes.",
                    "From **Dashboard**, tap a card to view details; use the **status pill** to set Pending, In Progress, or Done.",
                    "Any job with a status **other than Pending** is automatically included in **Timesheets** for that week.",
                    "Finished work also appears in **Yellow Sheet** grouped by Job # for the selected week.",
                    "Use **Share** on a job, Yellow Sheet, or Timesheet to send via Messages, Mail, or save as PDF."
                ],
                action: { showingCreateJob = true }
            ),
            HelpTopic(
                title: "Create Job",
                icon: "plus.circle.fill",
                summary: "Add a new job with address, assignees, photos, and notes.",
                bullets: [
                    "Job Number** is required. Example: `12345` 'ask Rick' or '?'.",
                    "Enter the address for the job.",
                    "Status** controls workflow. Change to any of the preset options or a custom one when appropriate.",
                    "The status is like at the end of the day when you send in yor jobs and say “1234 example st is done” or 1234 example st needs underground”.",
                    "Later after the jobs been created you can click on it to include the materials or any notes you might need to add.",
                    "Photos**: attach before/after shots; they upload and sync to your account. These can be included when sharing."
                ],
                action: { showingCreateJob = true }
            ),
            HelpTopic(
                title: "Statuses & Workflow",
                icon: "checkmark.circle",
                summary: "How statuses drive Timesheets and Yellow Sheets.",
                bullets: [
                    "Jobs start as **Pending** and are **excluded** from Timesheets/Yellow Sheet (until changed).",
                    "Once a status is changed to any status besides pending they get added to your Timesheet/YellowSheet automatically.",
                    "Change a status anytime from **Dashboard** or **tapping the job itself on the dashboard** to update instantly."
                ],
                action: { navigation.navigate(to: .dashboard) }
            ),
            HelpTopic(
                title: "Dashboard",
                icon: "rectangle.grid.2x2",
                summary: "Today’s jobs, quick status changes, maps, and sharing.",
                bullets: [
                    "The dashboard is where you handle creating and managing your jobs for the day or week.",
                    "If location services are enabled jobs will be sorted from closest-furthest or vise versa. You can change this in your settings.",
                    "Tap the **map** button to open directions to a job in your selected maps app.",
                    "Tap **share** to send job details and attached photos.",
                    "Use the date picker to jump to another day."
                ],
                action: { navigation.navigate(to: .dashboard) }
            ),
            HelpTopic(
                title: "Timesheets",
                icon: "clock",
                summary: "Your jobs get automatically added.",
                bullets: [
                    "Pick a week; your **non-Pending** jobs for that week appear automatically.",
                    "Enter Gibson and CableSouth hours per day.",
                    "Your past timesheets are also always accessible here. just simpy change the week..",
                    "Use **Print** to AirPrint or **Share** to send/save the PDF."
                ],
                action: { navigation.navigate(to: .timesheets) }
            ),
            HelpTopic(
                title: "Yellow Sheet",
                icon: "doc.text",
                summary: "Weekly jobs grouped by Job # (non-Pending only).",
                bullets: [
                    "Select a week at the top; swipe to change weeks.",
                    "you can always access previous weeks here too if needed.",
                    "Shows any job with statuses that aren’t set to Pending)."
                    
                ],
                action: { navigation.navigate(to: .yellowSheet) }
            ),
            
            HelpTopic(
                title: "Route Mapper",
                icon: "map.fill",
                summary: "Drop poles, measure distance, export a route PDF.",
                bullets: [
                    "Search for a location, then **tap the map** to drop poles in order.",
                    "Long‑press to insert between points; drag to adjust; tap a pin for details.",
                    "Tap **share** to export a PDF of your route."
                ],
                action: { navigation.navigate(to: .maps) }
            ),
            HelpTopic(
                title: "Find a Partner",
                icon: "person.2.fill",
                summary: "Pair with a coworker to coordinate work.",
                bullets: [
                    "Send a **Request** to a coworker; they’ll **Approve** from their inbox.",
                    "When paired, everything you do will work together allowing you to easily update jobs, this feature is useful for timesheets when one person  isn’t here.",
                    "Unpair anytime from the Partner screen."
                ],
                action: { navigation.navigate(to: .findPartner) }
            ),
            HelpTopic(
                title: "Account & Settings",
                icon: "gearshape.fill",
                summary: "Maps provider, notifications, sign‑out, and delete account.",
                bullets: [
                    "Switch between **Apple** and **Google** Maps.",
                    "Enable **arrival notifications** for today’s route.",
                    "Manage account and sign out from here."
                ],
                action: { navigation.navigate(to: .settings) }
            )
        ]
    }

    private var filteredTopics: [HelpTopic] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return topics }
        return topics.filter { t in
            (t.title + " " + t.summary + " " + t.bullets.joined(separator: " "))
                .lowercased()
                .contains(q)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Match your app’s gradient
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.14, blue: 0.18),
                         Color(red: 0.20, green: 0.45, blue: 0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header + search
                    VStack(spacing: 10) {
                        Text("Help Center")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            TextField("Search help…", text: $query)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                   

                    // Adaptive grid (great on iPad)
                    let columns = [GridItem(.adaptive(minimum: 280), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredTopics) { topic in
                            Button { selectedTopic = topic } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(topic.title, systemImage: topic.icon)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(topic.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                            }
                            .buttonStyle(.plain)
                            .helpGlassCard(cornerRadius: 16)
                        }
                    }

                    // Support block
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Need more help?")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Tap a topic for step‑by‑step instructions. Remember: jobs marked **In Progress** or **Done** are auto‑included in **Timesheets** and **Yellow Sheet** for the appropriate week.")
                            .foregroundStyle(.white.opacity(0.8))

                        HStack(spacing: 12) {
                            Button {
                                if let url = URL(string: "mailto:support@example.com") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Email Support", systemImage: "envelope.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .helpGlassCard(cornerRadius: 14)

                            
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showingCreateJob) {
            NavigationStack { CreateJobView() }
        }
        .sheet(item: $selectedTopic) { topic in
            TopicDetailSheet(topic: topic)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // Topic detail sheet
    fileprivate struct TopicDetailSheet: View {
        fileprivate let topic: HelpTopic
        @Environment(\.dismiss) private var dismiss

        fileprivate init(topic: HelpTopic) {
            self.topic = topic
        }

        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(topic.title, systemImage: topic.icon)
                            .font(.title2.bold())
                        ForEach(topic.bullets, id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .imageScale(.small)
                                    .foregroundStyle(.green)
                                Text(line)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let action = topic.action {
                            Button {
                                action()
                                dismiss()
                            } label: {
                                Label("Try it now", systemImage: "arrow.right.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .helpGlassCard(cornerRadius: 14)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Guide")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}

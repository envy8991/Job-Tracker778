//
//  HelpCenterView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 9/6/25.
//
import CoreLocation   // for distance / CLLocation
import SwiftUI
import UIKit // for UIImage in share attachments

// MARK: – Help Center
struct HelpCenterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var navigation: AppNavigationViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var query: String = ""
    @State private var showingCreateJob = false
    @State fileprivate var selectedTopic: HelpTopic? = nil

    private let supportMailURL = URL(string: "mailto:qathom8991@gmail.com")!

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
                summary: "End-to-end checklist from creating a job to sharing paperwork.",
                bullets: [
                    "**Step 1:** From the **Dashboard**, tap **Create Job** (plus button) to capture the job #, address, crew, and schedule.",
                    "**Step 2:** Save, then tap the new job card to adjust assignments, notes, materials, and attach progress photos as work continues.",
                    "**Step 3:** Move the status to **In Progress** when you roll out and **Done** when complete—anything not Pending flows automatically into Timesheets and the Yellow Sheet.",
                    "**Step 4:** Open **Timesheets** to enter daily Gibson/CS hours; switch to **Yellow Sheet** to verify the week’s grouped jobs before submitting.",
                    "**Step 5:** Use **Share** or **Print** from a job, Timesheet, or Yellow Sheet to deliver a PDF recap to supervisors."
                ],
                action: { showingCreateJob = true }
            ),
            HelpTopic(
                title: "Create Job",
                icon: "plus.circle.fill",
                summary: "Capture a new job with address suggestions, crew assignments, and photos.",
                bullets: [
                    "**Step 1:** On the **Dashboard**, tap **Create Job** to open the full job form.",
                    "**Step 2:** Enter the required **Job #** and street address—pick from live suggestions to auto-fill quickly.",
                    "**Step 3:** Set the scheduled date, assign teammates, and choose an initial status (keep **Pending** until work starts).",
                    "**Step 4:** Record notes, materials, and reference numbers that the crew needs on-site.",
                    "**Step 5:** Attach photos or documents before saving so everything syncs to the cloud for later sharing."
                ],
                action: { showingCreateJob = true }
            ),
            HelpTopic(
                title: "Job Details & Updates",
                icon: "square.and.pencil",
                summary: "Edit addresses, statuses, materials, and photos after a job is created.",
                bullets: [
                    "**Step 1:** Tap any job card from the **Dashboard**, **Job Search**, or **Timesheets** to open the detail editor.",
                    "**Step 2:** Update the address or job number—autocomplete keeps suggestions active while you type.",
                    "**Step 3:** Use the **Status** menu to apply preset options or enter a custom label; changes sync instantly to partners.",
                    "**Step 4:** Log assignments, fiber type, materials, and notes in their dedicated sections so everything stays in one place.",
                    "**Step 5:** Manage the photo gallery: add new shots, select and delete old ones, or open any image full screen for review."
                ],
                action: { navigation.navigate(to: .dashboard) }
            ),
            HelpTopic(
                title: "Statuses & Workflow",
                icon: "checkmark.circle",
                summary: "Statuses control payroll feeds and keep partners in sync.",
                bullets: [
                    "**Step 1:** Open a job from the **Dashboard** or **Job Search** and review the colored status pill at the top.",
                    "**Step 2:** Tap the status to choose **Pending**, **In Progress**, **Done**, or a custom need such as Needs Underground.",
                    "**Step 3:** The updated status saves immediately and appears for your partner and supervisors.",
                    "**Step 4:** Any status other than Pending automatically includes the job in the current week’s **Timesheet** and **Yellow Sheet**.",
                    "**Step 5:** Switch back to Pending only when a job should drop off payroll tracking for the week."
                ],
                action: { navigation.navigate(to: .dashboard) }
            ),
            HelpTopic(
                title: "Dashboard",
                icon: "rectangle.grid.2x2",
                summary: "Plan the day, reorder routes, update statuses, and share job packets.",
                bullets: [
                    "**Step 1:** Swipe the weekday selector or tap the date header to jump to another day’s schedule.",
                    "**Step 2:** Review summary counts, then tap any job card for full details or adjust the status right from the list.",
                    "**Step 3:** Use the **map** button on a job to launch your preferred maps app for turn-by-turn directions.",
                    "**Step 4:** Tap **Share** on a job to generate a PDF packet with notes and photos for coworkers or inspectors.",
                    "**Step 5:** Hit **Create Job** at the top whenever new work comes in to keep the day organized."
                ],
                action: { navigation.navigate(to: .dashboard) }
            ),
            HelpTopic(
                title: "Job Search",
                icon: "magnifyingglass",
                summary: "Search the global job index by address, job number, status, or creator.",
                bullets: [
                    "**Step 1:** Switch to **Job Search** from the main tabs—the app preloads the shared search index.",
                    "**Step 2:** Type part of an address, job #, status, or teammate name; results update instantly as you type.",
                    "**Step 3:** Review grouped results—duplicate addresses collapse so you can see every submission and who created it.",
                    "**Step 4:** Tap a result to open its history, attachments, and notes without leaving the search flow.",
                    "**Step 5:** Need edits? Open the job from search and update status or details just like you would from the Dashboard."
                ],
                action: { navigation.navigate(to: .search) }
            ),
            HelpTopic(
                title: "Timesheets",
                icon: "clock",
                summary: "Log weekly hours and submit a PDF with the auto-filled job list.",
                bullets: [
                    "**Step 1:** Open **Timesheets** and use the week picker (arrows or calendar) to choose the Sunday you need.",
                    "**Step 2:** Fill in the header—add the supervisor and up to two worker names, then enter Gibson and CS hours per day.",
                    "**Step 3:** Scroll through the auto-populated job cards for each day; tap any job to open the detail editor for adjustments.",
                    "**Step 4:** Adjust daily totals if needed—the running weekly total updates at the bottom of the screen.",
                    "**Step 5:** Use the toolbar’s **PDF** button to generate, preview, print, or share the completed weekly packet."
                ],
                action: { navigation.navigate(to: .timesheets) }
            ),
            HelpTopic(
                title: "Past Timesheets",
                icon: "archivebox.fill",
                summary: "Review, reopen, or delete archived weekly submissions.",
                bullets: [
                    "**Step 1:** From the **More › Profile** screen, tap **View Past Timesheets** to open your history.",
                    "**Step 2:** Scroll the list—each entry shows the week start, total hours, and whether a PDF is saved.",
                    "**Step 3:** Tap a week to view the snapshot with supervisor, worker names, and daily totals.",
                    "**Step 4:** Choose **View PDF** (when available) to open or share the saved file for auditing.",
                    "**Step 5:** Swipe left on an entry to delete it from the archive if it was uploaded in error."
                ],
                action: { navigation.navigate(to: .profile) }
            ),
            HelpTopic(
                title: "Yellow Sheet",
                icon: "doc.text",
                summary: "Confirm non-pending jobs for the week before submitting payroll.",
                bullets: [
                    "**Step 1:** Go to **Yellow Sheet** and select the week with the picker or calendar sheet.",
                    "**Step 2:** Review grouped sections by Job #—every non-Pending job from you or your partner is included.",
                    "**Step 3:** Expand a job card to double-check notes, assignments, and materials for the inspector.",
                    "**Step 4:** Tap **Save Yellow Sheet** to capture the weekly summary and sync it to the archive.",
                    "**Step 5:** Use the share button on individual jobs (from Dashboard) if additional documentation is requested."
                ],
                action: { navigation.navigate(to: .yellowSheet) }
            ),
            HelpTopic(
                title: "Route Mapper",
                icon: "map.fill",
                summary: "Plot poles, measure footage, and export a polished route map.",
                bullets: [
                    "**Step 1:** Search for an address or drop a pin to center the map, then tap to place poles in order.",
                    "**Step 2:** Long-press between poles to insert a new point, drag to refine placement, or tap a pin for details.",
                    "**Step 3:** In the pole inspector, capture assignments, footage, notes, and photos for construction teams.",
                    "**Step 4:** Use the map-style picker and distance badge to confirm the path before exporting.",
                    "**Step 5:** Tap **Share** to generate a PDF route packet you can send or save for permits."
                ],
                action: { navigation.navigate(to: .maps) }
            ),
            HelpTopic(
                title: "Route Mapper Sessions & Markup",
                icon: "person.2.circle",
                summary: "Collaborate live, draw markups, and manage shared annotations.",
                bullets: [
                    "**Step 1:** Open **Route Mapper** and tap **Start Session** to host or **Join** to enter a coworker’s code.",
                    "**Step 2:** Share the session code or invite link; the online badge updates as teammates connect.",
                    "**Step 3:** Expand the markup drawer to pick drawing tools, shapes, colors, line widths, and underground dash styles.",
                    "**Step 4:** Use undo, delete, or clear actions to manage shared markups—changes broadcast instantly to everyone.",
                    "**Step 5:** When finished, end the session or export the PDF so the markup snapshot is saved with the route."
                ],
                action: { navigation.navigate(to: .maps) }
            ),
            HelpTopic(
                title: "Find a Partner",
                icon: "person.2.fill",
                summary: "Pair with a coworker so job updates and payroll stay synchronized.",
                bullets: [
                    "**Step 1:** Open **Find a Partner** to see your current pairing status at the top of the list.",
                    "**Step 2:** Browse coworkers—tap **Request** to send a pairing invite or approve/decline incoming requests.",
                    "**Step 3:** Once connected, your jobs, Timesheets, and Yellow Sheets stay aligned across both accounts.",
                    "**Step 4:** Use the outgoing and incoming sections to monitor pending requests or resend if needed.",
                    "**Step 5:** Tap **Unpair** whenever you need to switch partners; the change syncs immediately."
                ],
                action: { navigation.navigate(to: .findPartner) }
            ),
            HelpTopic(
                title: "Account & Settings",
                icon: "gearshape.fill",
                summary: "Tune routing preferences, notifications, themes, and account access.",
                bullets: [
                    "**Step 1:** Visit **Settings** to adjust appearance or open the theme editor for custom colors.",
                    "**Step 2:** Enable **Smart Routing** and choose closest- or farthest-first ordering to reorder the Dashboard.",
                    "**Step 3:** Toggle arrival alerts for today and pick Apple or Google for address suggestions.",
                    "**Step 4:** Review your profile information, then sign out or delete the account if needed.",
                    "**Step 5:** Use the support links for privacy info or email the team when you need help."
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

    private var navigationBarVisibility: Visibility {
        horizontalSizeClass == .compact ? .hidden : .automatic
    }

    var body: some View {
        ZStack(alignment: .top) {
            JTGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: JTSpacing.lg) {
                    VStack(alignment: .leading, spacing: JTSpacing.sm) {
                        Text("Help Center")
                            .font(JTTypography.screenTitle)
                            .foregroundStyle(JTColors.textPrimary)

                        JTTextField("Search help…", text: $query, icon: "magnifyingglass")
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }

                    let columns = [GridItem(.adaptive(minimum: 280), spacing: JTSpacing.md)]
                    LazyVGrid(columns: columns, spacing: JTSpacing.md) {
                        ForEach(filteredTopics) { topic in
                            Button { selectedTopic = topic } label: {
                                GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
                                    VStack(alignment: .leading, spacing: JTSpacing.sm) {
                                        Label(topic.title, systemImage: topic.icon)
                                            .font(JTTypography.headline)
                                            .foregroundStyle(JTColors.textPrimary)
                                        Text(topic.summary)
                                            .font(JTTypography.subheadline)
                                            .foregroundStyle(JTColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(JTSpacing.md)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
                        VStack(alignment: .leading, spacing: JTSpacing.md) {
                            Text("Need more help?")
                                .font(JTTypography.title3)
                                .foregroundStyle(JTColors.textPrimary)
                            Text("Use search to jump straight to a workflow, or reach out if you need a walkthrough tailored to your crew.")
                                .foregroundStyle(JTColors.textSecondary)

                            JTPrimaryButton("Email Support", systemImage: "envelope.fill") {
                                UIApplication.shared.open(supportMailURL)
                            }
                        }
                        .padding(JTSpacing.lg)
                    }
                }
                .padding(JTSpacing.lg)
            }
        }
        .sheet(isPresented: $showingCreateJob) {
            NavigationStack { CreateJobView() }
            .jtNavigationBarStyle()
        }
        .sheet(item: $selectedTopic) { topic in
            TopicDetailSheet(topic: topic)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(navigationBarVisibility, for: .navigationBar)
        .jtNavigationBarStyle()
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
                    VStack(alignment: .leading, spacing: JTSpacing.md) {
                        Label(topic.title, systemImage: topic.icon)
                            .font(.title2.bold())
                        ForEach(topic.bullets, id: \.self) { line in
                            HStack(alignment: .top, spacing: JTSpacing.sm) {
                                Image(systemName: "checkmark.circle")
                                    .imageScale(.small)
                                    .foregroundStyle(.green)
                                Text(line)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let action = topic.action {
                            JTPrimaryButton("Try it now", systemImage: "arrow.right.circle.fill") {
                                action()
                                dismiss()
                            }
                            .padding(.top, JTSpacing.md)
                        }
                    }
                    .padding(JTSpacing.lg)
                }
                .navigationTitle("Guide")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .jtNavigationBarStyle()
        }
    }
}

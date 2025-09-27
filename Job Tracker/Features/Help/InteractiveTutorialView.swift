import SwiftUI

enum TutorialStageType: String, CaseIterable, Identifiable {
    case auth
    case dashboard
    case createJob
    case timesheet

    var id: String { rawValue }
}

struct TutorialStage: Identifiable, Equatable {
    let type: TutorialStageType
    let title: String
    let caption: String
    let iconName: String
    let checklist: [String]

    var id: TutorialStageType { type }
}

extension TutorialStage {
    static func defaultStages() -> [TutorialStage] {
        [
            TutorialStage(
                type: .auth,
                title: "Preview account actions",
                caption: "Switch between Sign In, Sign Up, and Reset to see how each form adapts.",
                iconName: "sparkles.rectangle.stack",
                checklist: [
                    "Flip the segmented control through every authentication step.",
                    "Review the sample forms and helper copy.",
                    "Once you've visited all three, the next stage unlocks."
                ]
            ),
            TutorialStage(
                type: .dashboard,
                title: "Walk the jobs dashboard",
                caption: "Practice changing a job's status and preview the daily share sheet.",
                iconName: "calendar",
                checklist: [
                    "Use the weekday picker to scan the crew's schedule.",
                    "Tap the share button in the header to stage the daily summary.",
                    "Update a job's status pill to see how lists react."
                ]
            ),
            TutorialStage(
                type: .createJob,
                title: "Create a sample job",
                caption: "Fill the required fields, pick a status, and press Create Job to continue.",
                iconName: "plus.circle.fill",
                checklist: [
                    "Enter a job number and confirm the address/date look good.",
                    "Open the status menu to choose the right workflow.",
                    "Press Create Job to capture the practice entry."
                ]
            ),
            TutorialStage(
                type: .timesheet,
                title: "Tune the weekly timesheet",
                caption: "Adjust worker hours and slide between weeks before finishing the tutorial.",
                iconName: "clock.badge.checkmark",
                checklist: [
                    "Pick a different Week of value to see how the sheet rewinds.",
                    "Edit a crew member's hours for one of the sample jobs.",
                    "All set? Save the update to mark the tutorial complete."
                ]
            )
        ]
    }
}

@MainActor
final class InteractiveTutorialViewModel: ObservableObject {
    @Published private(set) var stages: [TutorialStage]
    @Published var currentStageIndex: Int
    @Published private(set) var completion: [TutorialStageType: Bool]

    init(savedIndex: Int = 0, completedStages: Set<TutorialStageType> = []) {
        let defaults = TutorialStage.defaultStages()
        stages = defaults
        let safeIndex = defaults.indices.contains(savedIndex) ? savedIndex : 0
        currentStageIndex = safeIndex
        completion = Dictionary(uniqueKeysWithValues: defaults.map { stage in
            (stage.type, completedStages.contains(stage.type))
        })
    }

    var currentStage: TutorialStage {
        stages[currentStageIndex]
    }

    func setStage(_ type: TutorialStageType, completed: Bool) {
        completion[type] = completed
    }

    func isStageComplete(_ type: TutorialStageType) -> Bool {
        completion[type] ?? false
    }

    func advance() {
        guard currentStageIndex < stages.count - 1 else { return }
        currentStageIndex += 1
    }

    func goBack() {
        guard currentStageIndex > 0 else { return }
        currentStageIndex -= 1
    }

    var isTutorialComplete: Bool {
        !stages.isEmpty && stages.allSatisfy { stage in
            completion[stage.type] ?? false
        }
    }
}

// MARK: - Stage Models

@MainActor
final class AuthTutorialStageModel: ObservableObject {
    enum Step: String, CaseIterable, Identifiable {
        case signIn
        case signUp
        case reset

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Sign Up"
            case .reset: return "Reset"
            }
        }

        var subtitle: String {
            switch self {
            case .signIn:
                return "Use your crew email and password to jump into work."
            case .signUp:
                return "Fill out basic details so we can build your dashboard."
            case .reset:
                return "Request a reset link when someone forgets their password."
            }
        }
    }

    @Published private(set) var visitedSteps: Set<Step>
    @Published var selectedStep: Step

    init(selectedStep: Step = .signIn) {
        self.selectedStep = selectedStep
        visitedSteps = [selectedStep]
    }

    var isActionComplete: Bool {
        visitedSteps.count == Step.allCases.count
    }

    func select(step: Step) {
        selectedStep = step
        visitedSteps.insert(step)
    }

    func restoreCompletedState() {
        visitedSteps = Set(Step.allCases)
    }
}

@MainActor
final class DashboardTutorialStageModel: ObservableObject {
    struct Job: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var address: String
        var status: Status
    }

    enum Status: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case needsAerial = "Needs Aerial"
        case done = "Done"
        case custom = "Custom"

        var id: String { rawValue }

        var symbolName: String {
            switch self {
            case .pending: return "hourglass"
            case .needsAerial: return "airplane"
            case .done: return "checkmark.circle"
            case .custom: return "sparkles"
            }
        }
    }

    @Published var selectedDayIndex: Int
    @Published var jobs: [Job]
    @Published private(set) var didChangeStatus = false
    @Published private(set) var didTapShare = false

    init() {
        selectedDayIndex = 0
        jobs = [
            Job(title: "Splice drop", address: "711 Post Oak Ct", status: .pending),
            Job(title: "Aerial survey", address: "108 Amber Wave Blvd", status: .needsAerial),
            Job(title: "Fiber pull", address: "1436 Lyonia Dr", status: .pending)
        ]
    }

    var isActionComplete: Bool {
        didChangeStatus && didTapShare
    }

    func changeStatus(for jobID: UUID, to status: Status) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        if jobs[index].status != status {
            jobs[index].status = status
            didChangeStatus = true
        }
    }

    func recordShareTap() {
        didTapShare = true
    }

    func restoreCompletedState() {
        didChangeStatus = true
        didTapShare = true
    }
}

@MainActor
final class CreateJobTutorialStageModel: ObservableObject {
    enum StatusOption: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case aerial = "Needs Aerial"
        case ug = "Underground"
        case done = "Done"

        var id: String { rawValue }
    }

    @Published var address: String
    @Published var date: Date
    @Published var jobNumber: String
    @Published var status: StatusOption
    @Published var notes: String
    @Published private(set) var didSubmit = false

    init() {
        address = "2114 Charter Ridge Dr"
        date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        jobNumber = ""
        status = .pending
        notes = "Install drop line and capture post-trip photos."
    }

    var isActionComplete: Bool { didSubmit }

    func attemptSubmit() -> Bool {
        let trimmed = jobNumber.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        didSubmit = true
        return true
    }

    func resetSubmission() {
        didSubmit = false
    }

    func restoreCompletedState() {
        didSubmit = true
    }
}

@MainActor
final class TimesheetTutorialStageModel: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let id = UUID()
        var workerName: String
        var jobName: String
        var hours: Double
    }

    @Published var selectedWeekIndex: Int
    @Published var entries: [Entry]
    @Published private(set) var didEditHours = false

    let sampleWeeks: [String]

    init() {
        sampleWeeks = ["Week of Dec 2", "Week of Dec 9", "Week of Dec 16"]
        selectedWeekIndex = 0
        entries = [
            Entry(workerName: "Holly V.", jobName: "Splice drop", hours: 7.5),
            Entry(workerName: "Andre M.", jobName: "Fiber pull", hours: 6.0),
            Entry(workerName: "Zara L.", jobName: "UG bore", hours: 5.0)
        ]
    }

    var isActionComplete: Bool { didEditHours }

    func updateHours(for entryID: UUID, to hours: Double) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        if entries[index].hours != hours {
            entries[index].hours = hours
            didEditHours = true
        }
    }

    func restoreCompletedState() {
        didEditHours = true
    }
}

// MARK: - Interactive Tutorial View

@MainActor
struct InteractiveTutorialView: View {
    private enum StorageKeys {
        static let stageIndex = "interactiveTutorialCurrentStage"
        static let completedStages = "interactiveTutorialCompletedStages"
    }

    @StateObject private var viewModel: InteractiveTutorialViewModel

    @StateObject private var authStageModel = AuthTutorialStageModel()
    @StateObject private var dashboardStageModel = DashboardTutorialStageModel()
    @StateObject private var createJobStageModel = CreateJobTutorialStageModel()
    @StateObject private var timesheetStageModel = TimesheetTutorialStageModel()

    @AppStorage(StorageKeys.stageIndex) private var storedStageIndex: Int = 0
    @AppStorage(StorageKeys.completedStages) private var storedCompletedStages: String = ""
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    var onComplete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var didSyncInitialState = false

    init(onComplete: (() -> Void)? = nil) {
        let savedIndex = UserDefaults.standard.integer(forKey: StorageKeys.stageIndex)
        let rawCompleted = UserDefaults.standard.string(forKey: StorageKeys.completedStages) ?? ""
        let completedSet = Set(rawCompleted.split(separator: ",").compactMap { TutorialStageType(rawValue: String($0)) })
        _viewModel = StateObject(wrappedValue: InteractiveTutorialViewModel(savedIndex: savedIndex, completedStages: completedSet))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JTGradients.background
                    .ignoresSafeArea()

                VStack(spacing: JTSpacing.lg) {
                    header

                    ScrollView {
                        VStack(alignment: .leading, spacing: JTSpacing.xl) {
                            StageSummaryView(stage: viewModel.currentStage, index: viewModel.currentStageIndex, total: viewModel.stages.count)

                            instructionsList

                            practiceSection
                        }
                        .padding(.horizontal, JTSpacing.lg)
                        .padding(.vertical, JTSpacing.lg)
                    }

                    controls
                        .padding(.horizontal, JTSpacing.lg)
                        .padding(.bottom, JTSpacing.xl)
                }
            }
            .navigationTitle("Interactive Tutorial")
            .navigationBarTitleDisplayMode(.inline)
            .jtNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if onComplete != nil {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .onAppear {
                syncStageModelsIfNeeded()
            }
            .onChange(of: viewModel.currentStageIndex) { newValue in
                storedStageIndex = newValue
            }
            .onChange(of: viewModel.completion) { newValue in
                storedCompletedStages = encodeCompletedStages(newValue)
            }
        }
    }

    private var header: some View {
        VStack(spacing: JTSpacing.sm) {
            Text("Step \(viewModel.currentStageIndex + 1) of \(viewModel.stages.count)")
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)

            ProgressView(value: Double(viewModel.currentStageIndex + (viewModel.isStageComplete(viewModel.currentStage.type) ? 1 : 0)), total: Double(viewModel.stages.count))
                .tint(JTColors.accent)
        }
        .padding(.top, JTSpacing.xl)
    }

    private var instructionsList: some View {
        VStack(alignment: .leading, spacing: JTSpacing.md) {
            Text("How to complete this step")
                .font(JTTypography.title3)
                .foregroundStyle(JTColors.textPrimary)

            ForEach(Array(viewModel.currentStage.checklist.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: JTSpacing.sm) {
                    Text("\(index + 1).")
                        .font(JTTypography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(JTColors.accent)
                    Text(item)
                        .font(JTTypography.body)
                        .foregroundStyle(JTColors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var practiceSection: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
            VStack(alignment: .leading, spacing: JTSpacing.lg) {
                practiceView(for: viewModel.currentStage.type)
            }
            .padding(JTSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
        }
        .coordinateSpace(name: TutorialHighlightOverlay.coordinateSpaceName)
        .overlayPreferenceValue(TutorialHighlightPreferenceKey.self) { targets in
            GeometryReader { proxy in
                let items = targets.map { target -> TutorialHighlightItem in
                    let rect = proxy[target.anchor, in: SwiftUI.CoordinateSpace.named(TutorialHighlightOverlay.coordinateSpaceName)].insetBy(dx: -target.padding, dy: -target.padding)
                    return TutorialHighlightItem(
                        id: target.id,
                        frame: rect,
                        message: target.message,
                        arrowEdge: target.arrowEdge,
                        shape: target.shape,
                        showsPulse: target.showsPulse
                    )
                }
                TutorialHighlightOverlay(items: items)
            }
        }
    }

    @ViewBuilder
    private func practiceView(for type: TutorialStageType) -> some View {
        switch type {
        case .auth:
            AuthTutorialStageView(model: authStageModel) { isComplete in
                viewModel.setStage(.auth, completed: isComplete)
            }
        case .dashboard:
            DashboardTutorialStageView(model: dashboardStageModel) { isComplete in
                viewModel.setStage(.dashboard, completed: isComplete)
            }
        case .createJob:
            CreateJobTutorialStageView(model: createJobStageModel) { isComplete in
                viewModel.setStage(.createJob, completed: isComplete)
            }
        case .timesheet:
            TimesheetTutorialStageView(model: timesheetStageModel) { isComplete in
                viewModel.setStage(.timesheet, completed: isComplete)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: JTSpacing.md) {
            if viewModel.currentStageIndex > 0 {
                Button("Back") {
                    if reduceMotion {
                        viewModel.goBack()
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            viewModel.goBack()
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, JTSpacing.md)
                .padding(.horizontal, JTSpacing.lg)
                .jtGlassBackground(cornerRadius: JTShapes.buttonCornerRadius)
            }

            Spacer()

            let isLastStage = viewModel.currentStageIndex == viewModel.stages.count - 1
            let canAdvance = viewModel.isStageComplete(viewModel.currentStage.type)

            Button {
                if isLastStage {
                    finishTutorial()
                } else {
                    if reduceMotion {
                        viewModel.advance()
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            viewModel.advance()
                        }
                    }
                }
            } label: {
                Text(isLastStage ? "Finish" : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.jtPrimary)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.5)
        }
    }

    private func finishTutorial() {
        hasSeenTutorial = true
        storedStageIndex = viewModel.currentStageIndex
        storedCompletedStages = encodeCompletedStages(viewModel.completion)
        if reduceMotion {
            onComplete?()
            dismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                onComplete?()
                dismiss()
            }
        }
    }

    private func encodeCompletedStages(_ completion: [TutorialStageType: Bool]) -> String {
        TutorialStageType.allCases
            .filter { completion[$0] ?? false }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private func syncStageModelsIfNeeded() {
        guard !didSyncInitialState else { return }
        didSyncInitialState = true

        if viewModel.isStageComplete(.auth) {
            authStageModel.restoreCompletedState()
        }
        if viewModel.isStageComplete(.dashboard) {
            dashboardStageModel.restoreCompletedState()
        }
        if viewModel.isStageComplete(.createJob) {
            createJobStageModel.restoreCompletedState()
        }
        if viewModel.isStageComplete(.timesheet) {
            timesheetStageModel.restoreCompletedState()
        }
    }
}

// MARK: - Stage Summary Header

@MainActor
private struct StageSummaryView: View {
    let stage: TutorialStage
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            Label(stage.title, systemImage: stage.iconName)
                .font(JTTypography.title)
                .foregroundStyle(JTColors.textPrimary)

            Text(stage.caption)
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Stage Practice Views

@MainActor
private struct AuthTutorialStageView: View {
    @ObservedObject var model: AuthTutorialStageModel
    var completionChanged: (Bool) -> Void

    @State private var email = "crew@jobtracker.app"
    @State private var password = "••••••••"
    @State private var confirmPassword = "••••••••"
    @State private var resetEmail = "crew@jobtracker.app"
    @State private var banner: String? = nil

    private var selectionBinding: Binding<AuthTutorialStageModel.Step> {
        Binding(
            get: { model.selectedStep },
            set: { step in
                model.select(step: step)
                completionChanged(model.isActionComplete)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            Picker("Authentication actions", selection: selectionBinding) {
                ForEach(AuthTutorialStageModel.Step.allCases) { step in
                    Text(step.title).tag(step)
                }
            }
            .pickerStyle(.segmented)
            .tutorialHighlight(
                id: "auth.segmented",
                message: "Toggle through Sign In, Sign Up, and Reset to preview each workflow.",
                arrowEdge: .top,
                shape: .rounded(cornerRadius: 12),
                showsPulse: !model.isActionComplete
            )

            GlassCard(cornerRadius: JTShapes.cardCornerRadius) {
                VStack(alignment: .leading, spacing: JTSpacing.md) {
                    Text(model.selectedStep.subtitle)
                        .font(JTTypography.body)
                        .foregroundStyle(JTColors.textSecondary)

                    switch model.selectedStep {
                    case .signIn:
                        VStack(alignment: .leading, spacing: JTSpacing.sm) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            SecureField("Password", text: $password)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            JTPrimaryButton("Sign In") {
                                banner = "Signed in as crew lead."
                            }
                        }
                    case .signUp:
                        VStack(alignment: .leading, spacing: JTSpacing.sm) {
                            TextField("Crew name", text: .constant("South Ridge Crew"))
                                .disabled(true)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            TextField("Email", text: $email)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            SecureField("Password", text: $password)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            SecureField("Confirm password", text: $confirmPassword)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            JTPrimaryButton("Create Account") {
                                banner = "Crew account staged — invite pending approval."
                            }
                        }
                    case .reset:
                        VStack(alignment: .leading, spacing: JTSpacing.sm) {
                            TextField("Account email", text: $resetEmail)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            JTPrimaryButton("Send Reset Link") {
                                banner = "Reset email sent to \(resetEmail)."
                            }
                        }
                    }
                }
                .padding(JTSpacing.lg)
            }

            if let banner {
                Text(banner)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.success)
                    .transition(.opacity)
            }

            if model.isActionComplete {
                Label("You've visited every form", systemImage: "checkmark.seal")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.success)
            }
        }
        .onAppear {
            completionChanged(model.isActionComplete)
        }
    }
}

@MainActor
private struct DashboardTutorialStageView: View {
    @ObservedObject var model: DashboardTutorialStageModel
    var completionChanged: (Bool) -> Void

    @State private var showingShareToast = false

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            Picker("Weekday", selection: $model.selectedDayIndex) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Jobs — \(weekdays[model.selectedDayIndex])")
                            .font(JTTypography.title3)
                            .foregroundStyle(JTColors.textPrimary)
                        Text("Swipe through jobs, share the plan, or adjust statuses.")
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                    Spacer()
                    Button {
                        model.recordShareTap()
                        showingShareToast = true
                        completionChanged(model.isActionComplete)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showingShareToast = false
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.medium)
                            .padding(10)
                            .background(JTColors.accent.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .tutorialHighlight(
                        id: "dashboard.share",
                        message: "Share the daily jobs plan once you've reviewed statuses.",
                        arrowEdge: .top,
                        shape: .circle,
                        showsPulse: !model.didTapShare
                    )
                }

                if showingShareToast {
                    Label("Daily share staged", systemImage: "checkmark.circle.fill")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.success)
                        .transition(.opacity)
                }
            }

            VStack(spacing: JTSpacing.md) {
                ForEach(model.jobs) { job in
                    GlassCard(cornerRadius: JTShapes.cardCornerRadius) {
                        VStack(alignment: .leading, spacing: JTSpacing.sm) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.title)
                                        .font(JTTypography.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(JTColors.textPrimary)
                                    Text(job.address)
                                        .font(JTTypography.caption)
                                        .foregroundStyle(JTColors.textSecondary)
                                }
                                Spacer()
                                statusMenu(for: job)
                                    .tutorialHighlight(
                                        id: "dashboard.status.\(job.id)",
                                        message: "Tap the status pill to move work between Pending, Needs Aerial, Done, or Custom.",
                                        arrowEdge: .bottom,
                                        shape: .capsule,
                                        showsPulse: !model.didChangeStatus
                                    )
                            }

                            HStack(spacing: JTSpacing.sm) {
                                Label("Directions", systemImage: "map")
                                    .font(JTTypography.caption)
                                    .foregroundStyle(JTColors.textSecondary)
                                Divider()
                                Label("Notes", systemImage: "text.justify")
                                    .font(JTTypography.caption)
                                    .foregroundStyle(JTColors.textSecondary)
                            }
                        }
                        .padding(JTSpacing.lg)
                    }
                }
            }
        }
        .onChange(of: model.didChangeStatus) { newValue in
            completionChanged(model.isActionComplete)
        }
        .onChange(of: model.didTapShare) { _ in
            completionChanged(model.isActionComplete)
        }
        .onAppear {
            completionChanged(model.isActionComplete)
        }
    }

    @ViewBuilder
    private func statusMenu(for job: DashboardTutorialStageModel.Job) -> some View {
        Menu {
            ForEach(DashboardTutorialStageModel.Status.allCases) { status in
                Button {
                    model.changeStatus(for: job.id, to: status)
                    completionChanged(model.isActionComplete)
                } label: {
                    Label(status.rawValue, systemImage: status.symbolName)
                }
            }
        } label: {
            HStack(spacing: JTSpacing.xs) {
                Circle()
                    .fill(color(for: job.status))
                    .frame(width: 10, height: 10)
                Text(job.status.rawValue)
                    .font(JTTypography.caption.weight(.semibold))
            }
            .padding(.horizontal, JTSpacing.md)
            .padding(.vertical, JTSpacing.xs)
            .background(JTColors.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func color(for status: DashboardTutorialStageModel.Status) -> Color {
        switch status {
        case .pending: return Color.yellow
        case .needsAerial: return Color.orange
        case .done: return Color.green
        case .custom: return Color.purple
        }
    }
}

@MainActor
private struct CreateJobTutorialStageView: View {
    @ObservedObject var model: CreateJobTutorialStageModel
    var completionChanged: (Bool) -> Void

    @State private var showValidationError = false

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            Text("Enter job details")
                .font(JTTypography.title3)
                .foregroundStyle(JTColors.textPrimary)

            VStack(alignment: .leading, spacing: JTSpacing.md) {
                TextField("Enter address", text: $model.address)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                DatePicker("Select date", selection: $model.date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tutorialHighlight(
                        id: "create.date",
                        message: "Tap to adjust when this job should appear on the dashboard calendar.",
                        arrowEdge: .top,
                        shape: .rounded(cornerRadius: 12),
                        showsPulse: false
                    )

                Menu {
                    ForEach(CreateJobTutorialStageModel.StatusOption.allCases) { status in
                        Button(status.rawValue) {
                            model.status = status
                        }
                    }
                } label: {
                    HStack {
                        Text("Status: \(model.status.rawValue)")
                            .font(JTTypography.body)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                    }
                    .padding()
                    .background(JTColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .tutorialHighlight(
                    id: "create.status",
                    message: "Choose a status so supervisors know how to route the crew.",
                    arrowEdge: .trailing,
                    shape: .rounded(cornerRadius: 12),
                    showsPulse: !model.isActionComplete
                )

                TextField("Job number (required)", text: $model.jobNumber)
                    .keyboardType(.numbersAndPunctuation)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextEditor(text: $model.notes)
                    .frame(height: 90)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            JTPrimaryButton(model.isActionComplete ? "Job Recorded" : "Create Job") {
                showValidationError = !model.attemptSubmit()
                completionChanged(model.isActionComplete)
            }
            .disabled(model.isActionComplete)
            .opacity(model.isActionComplete ? 0.6 : 1)
            .tutorialHighlight(
                id: "create.submit",
                message: "Fill the required fields and press Create Job to log the work.",
                arrowEdge: .bottom,
                shape: .rounded(cornerRadius: 16),
                showsPulse: !model.isActionComplete
            )

            if showValidationError {
                Text("Enter a job number before saving.")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.error)
            }

            if model.isActionComplete {
                Label("Practice job saved", systemImage: "checkmark.seal")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.success)
            }
        }
        .onAppear {
            completionChanged(model.isActionComplete)
        }
    }
}

@MainActor
private struct TimesheetTutorialStageView: View {
    @ObservedObject var model: TimesheetTutorialStageModel
    var completionChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            Menu {
                ForEach(Array(model.sampleWeeks.enumerated()), id: \.offset) { index, week in
                    Button(week) {
                        model.selectedWeekIndex = index
                    }
                }
            } label: {
                HStack {
                    Text(model.sampleWeeks[model.selectedWeekIndex])
                        .font(JTTypography.body)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "calendar")
                }
                .padding()
                .background(JTColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .tutorialHighlight(
                id: "timesheet.week",
                message: "Use Week of… to rewind or advance the crew's entries.",
                arrowEdge: .top,
                shape: .rounded(cornerRadius: 12),
                showsPulse: !model.isActionComplete
            )

            VStack(spacing: JTSpacing.md) {
                ForEach(model.entries) { entry in
                    GlassCard(cornerRadius: JTShapes.cardCornerRadius) {
                        VStack(alignment: .leading, spacing: JTSpacing.sm) {
                            Text(entry.workerName)
                                .font(JTTypography.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(JTColors.textPrimary)
                            Text(entry.jobName)
                                .font(JTTypography.caption)
                                .foregroundStyle(JTColors.textSecondary)

                            Stepper(value: Binding(
                                get: { entryValue(for: entry.id) },
                                set: { newValue in
                                    model.updateHours(for: entry.id, to: newValue)
                                    completionChanged(model.isActionComplete)
                                }
                            ), in: 0...12, step: 0.5) {
                                Text("Hours: \(entryValue(for: entry.id), specifier: "%.1f")")
                                    .font(JTTypography.body)
                            }
                            .tutorialHighlight(
                                id: "timesheet.stepper.\(entry.id)",
                                message: "Adjust a worker's hours for the job to mark this stage complete.",
                                arrowEdge: .bottom,
                                shape: .rounded(cornerRadius: 12),
                                showsPulse: !model.isActionComplete
                            )
                        }
                        .padding(JTSpacing.lg)
                    }
                }
            }

            if model.isActionComplete {
                Label("Hours updated", systemImage: "checkmark.seal")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.success)
            }
        }
        .onAppear {
            completionChanged(model.isActionComplete)
        }
    }

    private func entryValue(for id: UUID) -> Double {
        model.entries.first(where: { $0.id == id })?.hours ?? 0
    }
}

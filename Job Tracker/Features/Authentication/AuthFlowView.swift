import SwiftUI

struct AuthFlowView: View {
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

        var headline: String {
            switch self {
            case .signIn: return "Welcome Back"
            case .signUp: return "Create Your Account"
            case .reset: return "Need a Reset?"
            }
        }

        var message: String {
            switch self {
            case .signIn:
                return "Sign in with the credentials you use across the Job Tracker apps."
            case .signUp:
                return "Fill in your crew details below so we can personalize your dashboard."
            case .reset:
                return "Enter the email tied to your Job Tracker account and we'll send a reset link."
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false

    @State private var selection: Step
    @State private var showingTutorial = false

    init(initialStep: Step = .signIn) {
        _selection = State(initialValue: initialStep)
    }

    var body: some View {
        ZStack(alignment: .top) {
            JTGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: JTSpacing.xl) {
                    header

                    Picker("Authentication actions", selection: $selection) {
                        ForEach(Step.allCases) { step in
                            Text(step.title).tag(step)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Authentication actions")

                    GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                              strokeColor: JTColors.glassSoftStroke,
                              strokeWidth: 1) {
                        VStack(alignment: .leading, spacing: JTSpacing.lg) {
                            switch selection {
                            case .signIn:
                                AuthLoginForm(
                                    onCreateAccount: transition(to: .signUp),
                                    onForgotPassword: transition(to: .reset)
                                )
                            case .signUp:
                                AuthSignUpForm(
                                    onShowSignIn: transition(to: .signIn)
                                )
                            case .reset:
                                PasswordResetForm(
                                    onBackToSignIn: transition(to: .signIn)
                                )
                            }
                        }
                        .padding(JTSpacing.lg)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.88), value: selection)

                    tutorialEntry
                }
                .padding(.horizontal, JTSpacing.lg)
                .padding(.vertical, JTSpacing.xl)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingTutorial) {
            NavigationStack {
                TutorialView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingTutorial = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if !hasSeenTutorial {
                                Button("Mark Complete") {
                                    hasSeenTutorial = true
                                    showingTutorial = false
                                }
                            }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        VStack(spacing: JTSpacing.sm) {
            Text(selection.headline)
                .font(JTTypography.screenTitle)
                .foregroundStyle(JTColors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(selection.message)
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, JTSpacing.lg)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selection)
    }

    private var tutorialEntry: some View {
        VStack(spacing: JTSpacing.sm) {
            Button {
                showingTutorial = true
            } label: {
                Label("Preview the onboarding tutorial", systemImage: "sparkles.tv")
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JTSpacing.md)
                    .padding(.horizontal, JTSpacing.lg)
                    .jtGlassBackground(cornerRadius: JTShapes.buttonCornerRadius,
                                       strokeColor: JTColors.glassSoftStroke,
                                       strokeWidth: 1)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the interactive walkthrough in a sheet")

            if hasSeenTutorial {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        hasSeenTutorial = false
                    }
                } label: {
                    Text("Reset tutorial progress for this device")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Next app launch will surface the tutorial again")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func transition(to step: Step) -> () -> Void {
        {
            if reduceMotion {
                selection = step
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    selection = step
                }
            }
        }
    }
}

// MARK: - Login Form

private struct AuthLoginForm: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var authError: String?
    @State private var isSubmitting = false
    @State private var hasAttemptedSubmit = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email
        case password
    }

    var onCreateAccount: () -> Void
    var onForgotPassword: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            VStack(spacing: JTSpacing.md) {
                JTTextField("Email Address",
                            text: $email,
                            icon: "envelope",
                            state: state(for: emailError, text: email),
                            supportingText: supportingMessage(for: emailError))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                JTTextField("Password",
                            text: $password,
                            icon: "lock",
                            isSecure: true,
                            state: state(for: passwordError, text: password),
                            supportingText: supportingMessage(for: passwordError))
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }

            if let authError {
                Text(authError)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.error)
                    .accessibilityLabel(authError)
            }

            JTPrimaryButton(isSubmitting ? "Signing In…" : "Sign In", systemImage: "arrow.right.circle.fill") {
                submit()
            }
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.7 : 1)

            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                Button("Forgot password?") {
                    onForgotPassword()
                }
                .buttonStyle(.plain)
                .font(JTTypography.subheadline)
                .foregroundStyle(JTColors.textSecondary)

                HStack(spacing: JTSpacing.xs) {
                    Text("Need an account?")
                        .font(JTTypography.subheadline)
                        .foregroundStyle(JTColors.textMuted)
                    Button("Create one") {
                        onCreateAccount()
                    }
                    .buttonStyle(.plain)
                    .font(JTTypography.subheadline)
                    .foregroundStyle(JTColors.accent)
                }
            }
        }
        .onChange(of: email) { _ in
            guard hasAttemptedSubmit else { return }
            emailError = email.validationEmailError
            authError = nil
        }
        .onChange(of: password) { _ in
            guard hasAttemptedSubmit else { return }
            passwordError = password.validationRequiredError(label: "password")
            authError = nil
        }
    }

    private func submit() {
        focusedField = nil
        hasAttemptedSubmit = true
        emailError = email.validationEmailError
        passwordError = password.validationRequiredError(label: "password")
        guard emailError == nil, passwordError == nil else { return }

        authError = nil
        isSubmitting = true
        authViewModel.signIn(email: email, password: password) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error = error {
                    if reduceMotion {
                        authError = error.localizedDescription
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            authError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private func state(for error: String?, text: String) -> JTInputState {
        if let error, hasAttemptedSubmit {
            return .error
        }
        if hasAttemptedSubmit && !text.isEmpty {
            return .success
        }
        return .neutral
    }

    private func supportingMessage(for error: String?) -> String? {
        guard hasAttemptedSubmit else { return nil }
        return error
    }
}

// MARK: - Sign Up Form

private struct AuthSignUpForm: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var position = "Aerial"

    @State private var firstNameError: String?
    @State private var lastNameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var signUpError: String?
    @State private var isSubmitting = false
    @State private var hasAttemptedSubmit = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case firstName
        case lastName
        case email
        case password
    }

    private let positions = ["Aerial", "Underground", "Nid", "Can"]

    var onShowSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            VStack(spacing: JTSpacing.md) {
                JTTextField("First Name",
                            text: $firstName,
                            icon: "person",
                            state: state(for: firstNameError, text: firstName),
                            supportingText: supportingMessage(for: firstNameError))
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .firstName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .lastName }

                JTTextField("Last Name",
                            text: $lastName,
                            icon: "person",
                            state: state(for: lastNameError, text: lastName),
                            supportingText: supportingMessage(for: lastNameError))
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .lastName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }

                JTTextField("Email Address",
                            text: $email,
                            icon: "envelope",
                            state: state(for: emailError, text: email),
                            supportingText: supportingMessage(for: emailError))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                JTTextField("Password",
                            text: $password,
                            icon: "lock",
                            isSecure: true,
                            state: state(for: passwordError, text: password),
                            supportingText: passwordSupportingMessage)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }

            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                Text("Crew Position")
                    .font(JTTypography.subheadline)
                    .foregroundStyle(JTColors.textSecondary)
                Picker("Crew Position", selection: $position) {
                    ForEach(positions, id: \.self) { pos in
                        Text(pos).tag(pos)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let signUpError {
                Text(signUpError)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.error)
            }

            JTPrimaryButton(isSubmitting ? "Creating Account…" : "Create Account", systemImage: "checkmark.circle.fill") {
                submit()
            }
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.7 : 1)

            Button("Already have an account? Sign in") {
                onShowSignIn()
            }
            .buttonStyle(.plain)
            .font(JTTypography.subheadline)
            .foregroundStyle(JTColors.textSecondary)
        }
        .onChange(of: firstName) { _ in
            guard hasAttemptedSubmit else { return }
            firstNameError = firstName.validationRequiredError(label: "first name")
            signUpError = nil
        }
        .onChange(of: lastName) { _ in
            guard hasAttemptedSubmit else { return }
            lastNameError = lastName.validationRequiredError(label: "last name")
            signUpError = nil
        }
        .onChange(of: email) { _ in
            guard hasAttemptedSubmit else { return }
            emailError = email.validationEmailError
            signUpError = nil
        }
        .onChange(of: password) { _ in
            guard hasAttemptedSubmit else { return }
            passwordError = password.validationPasswordError
            signUpError = nil
        }
    }

    private func submit() {
        focusedField = nil
        hasAttemptedSubmit = true

        firstNameError = firstName.validationRequiredError(label: "first name")
        lastNameError = lastName.validationRequiredError(label: "last name")
        emailError = email.validationEmailError
        passwordError = password.validationPasswordError

        guard firstNameError == nil,
              lastNameError == nil,
              emailError == nil,
              passwordError == nil else { return }

        signUpError = nil
        isSubmitting = true

        authViewModel.signUp(firstName: firstName,
                             lastName: lastName,
                             position: position,
                             email: email,
                             password: password) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error = error {
                    if reduceMotion {
                        signUpError = error.localizedDescription
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            signUpError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private func state(for error: String?, text: String) -> JTInputState {
        if let error, hasAttemptedSubmit {
            return .error
        }
        if hasAttemptedSubmit && !text.isEmpty {
            return .success
        }
        return .neutral
    }

    private func supportingMessage(for error: String?) -> String? {
        guard hasAttemptedSubmit else { return nil }
        return error
    }

    private var passwordSupportingMessage: String {
        if let passwordError, hasAttemptedSubmit {
            return passwordError
        }
        return "Use at least 8 characters."
    }
}

// MARK: - Password Reset Form

private struct PasswordResetForm: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var email = ""
    @State private var emailError: String?
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    @State private var hasAttemptedSubmit = false

    @FocusState private var focusedField: Bool

    var onBackToSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.lg) {
            JTTextField("Email Address",
                        text: $email,
                        icon: "envelope",
                        state: state,
                        supportingText: supportingMessage)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($focusedField)
                .submitLabel(.go)
                .onSubmit(sendReset)

            if let statusMessage {
                Text(statusMessage)
                    .font(JTTypography.caption)
                    .foregroundStyle(emailError == nil ? JTColors.success : JTColors.error)
            }

            JTPrimaryButton(isSubmitting ? "Sending…" : "Email Reset Link", systemImage: "paperplane.fill") {
                sendReset()
            }
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.7 : 1)

            Button("Back to sign in") {
                onBackToSignIn()
            }
            .buttonStyle(.plain)
            .font(JTTypography.subheadline)
            .foregroundStyle(JTColors.textSecondary)
        }
        .onChange(of: email) { _ in
            guard hasAttemptedSubmit else { return }
            emailError = email.validationEmailError
            statusMessage = nil
        }
    }

    private var state: JTInputState {
        if let emailError, hasAttemptedSubmit {
            return .error
        }
        if hasAttemptedSubmit && !email.isEmpty {
            return .success
        }
        return .neutral
    }

    private var supportingMessage: String? {
        if let emailError, hasAttemptedSubmit {
            return emailError
        }
        return "We'll send a secure link to reset your password."
    }

    private func sendReset() {
        focusedField = false
        hasAttemptedSubmit = true
        emailError = email.validationEmailError

        guard emailError == nil else {
            statusMessage = nil
            return
        }

        statusMessage = nil
        isSubmitting = true
        authViewModel.sendPasswordReset(email: email) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error = error {
                    if reduceMotion {
                        statusMessage = error.localizedDescription
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            statusMessage = error.localizedDescription
                        }
                    }
                    emailError = error.localizedDescription
                } else {
                    let message = "Check \(email) for reset instructions."
                    if reduceMotion {
                        statusMessage = message
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            statusMessage = message
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Validation Helpers

private extension String {
    var validationEmailError: String? {
        guard !isEmpty else { return "Email is required." }
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        if range(of: pattern, options: [.regularExpression, .caseInsensitive]) == nil {
            return "Enter a valid email address."
        }
        return nil
    }

    func validationRequiredError(label: String) -> String? {
        trimmed().isEmpty ? "Please enter your \(label)." : nil
    }

    var validationPasswordError: String? {
        if isEmpty {
            return "Password is required."
        }
        if count < 8 {
            return "Password must be at least 8 characters."
        }
        return nil
    }

    private func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

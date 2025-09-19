import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var position = "Aerial"
    @State private var errorMessage = ""
    
    let positions = ["Aerial", "Underground", "Nid", "Can"]

    var body: some View {
        ZStack {
            JTGradients.background
                .ignoresSafeArea()

            VStack(spacing: JTSpacing.xl) {
                Text("Sign Up")
                    .font(JTTypography.screenTitle)
                    .foregroundStyle(JTColors.textPrimary)

                GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
                    VStack(spacing: JTSpacing.md) {
                        JTTextField("First Name", text: $firstName, icon: "person")
                            .textInputAutocapitalization(.words)

                        JTTextField("Last Name", text: $lastName, icon: "person")
                            .textInputAutocapitalization(.words)

                        JTTextField("Email", text: $email, icon: "envelope")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .disableAutocorrection(true)

                        JTTextField("Password", text: $password, icon: "lock", isSecure: true)

                        Picker("Position", selection: $position) {
                            ForEach(positions, id: \.self) { pos in
                                Text(pos)
                            }
                        }
                        .pickerStyle(.segmented)

                        JTPrimaryButton("Create Account", systemImage: "checkmark.circle.fill") {
                            authViewModel.signUp(firstName: firstName,
                                                 lastName: lastName,
                                                 position: position,
                                                 email: email,
                                                 password: password) { error in
                                if let error = error {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(JTTypography.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, JTSpacing.sm)
                        }
                    }
                    .padding(JTSpacing.lg)
                }
                .padding(.horizontal, JTSpacing.lg)

                Spacer()
            }
            .padding(.top, JTSpacing.xl)
            .padding(.bottom, JTSpacing.lg)
        }
    }
}

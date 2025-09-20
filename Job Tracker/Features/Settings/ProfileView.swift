import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient.
                JTGradients.background(stops: 4)
                .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    if let user = authViewModel.currentUser {
                        Text("Name: \(user.firstName) \(user.lastName)")
                            .font(.title2)
                            .foregroundColor(JTColors.textPrimary)
                        Text("Position: \(user.position)")
                            .font(.headline)
                            .foregroundColor(JTColors.textSecondary)

                        NavigationLink(destination: PastTimesheetsView().environmentObject(authViewModel)) {
                            Text("View Past Timesheets")
                                .foregroundColor(JTColors.accent)
                        }
                        .padding(.top, 10)

                        NavigationLink(destination: PastYellowSheetsView().environmentObject(authViewModel)) {
                            Text("View Past Yellow Sheets")
                                .foregroundColor(JTColors.accent)
                        }
                        .padding(.top, 10)

                        Button("Sign Out") {
                            authViewModel.signOut()
                        }
                        .padding()
                        .background(JTColors.error)
                        .foregroundColor(JTColors.onAccent)
                        .cornerRadius(8)
                    } else {
                        Text("No user info available.")
                            .foregroundColor(JTColors.textSecondary)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}

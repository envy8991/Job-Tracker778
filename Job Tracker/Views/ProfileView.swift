import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient.
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.17254902, green: 0.24313726, blue: 0.3137255),
                        Color(red: 0.29803923, green: 0.6313726, blue: 0.6862745)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    if let user = authViewModel.currentUser {
                        Text("Name: \(user.firstName) \(user.lastName)")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Position: \(user.position)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        NavigationLink(destination: PastTimesheetsView().environmentObject(authViewModel)) {
                            Text("View Past Timesheets")
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        
                        NavigationLink(destination: PastYellowSheetsView().environmentObject(authViewModel)) {
                            Text("View Past Yellow Sheets")
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        
                        Button("Sign Out") {
                            authViewModel.signOut()
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text("No user info available.")
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}

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
            // Background gradient
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
                Text("Sign Up")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                TextField("First Name", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Position", selection: $position) {
                    ForEach(positions, id: \.self) { pos in
                        Text(pos)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Button("Create Account") {
                    authViewModel.signUp(firstName: firstName, lastName: lastName, position: position, email: email, password: password) { error in
                        if let error = error {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

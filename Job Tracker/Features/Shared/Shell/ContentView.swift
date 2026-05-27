//
//  ContentView.swift
//  Job Tracking Cable South
//
//  Created by Quinton  Thompson  on 1/30/25.
//


import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                AppShellView()
            } else {
                AuthFlowView()
            }
        }
        .onAppear {
            authViewModel.checkAuthState()
        }
    }
}
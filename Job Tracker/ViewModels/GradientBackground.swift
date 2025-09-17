//
//  GradientBackground.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 3/22/25.
//


//
//  ViewExtensions.swift
//  Job Tracking Cable South
//
//  Created by Quinton Thompson on 3/22/25.
//

import SwiftUI

struct GradientBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.2, blue: 0.35),
                    Color(red: 0.25, green: 0.35, blue: 0.45)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            content
        }
    }
}

extension View {
    /// Applies the shared gradient background used across the app.
    func gradientBackground() -> some View {
        self.modifier(GradientBackground())
    }
}

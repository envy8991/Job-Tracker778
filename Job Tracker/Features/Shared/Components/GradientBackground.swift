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
            JTGradients.background(stops: 4)
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

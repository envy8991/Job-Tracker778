//
//  TutorialView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/19/25.
//


import SwiftUI

struct TutorialView: View {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw: String = "apple" // "apple" or "google"
    
    var body: some View {
        TabView {
            TutorialPage(
                title: "Create Jobs Easily",
                description: "Tap **Create Job** to enter the job number and address. You can add it quickly and edit details later.",
                imageName: "plus.circle.fill"
            )

            TutorialPage(
                title: "Manage Your Dashboard",
                description: "Pick **Mon–Fri** to see jobs for the day, update status, or get directions. Long-press to reorder if needed.",
                imageName: "calendar"
            )

            TutorialPage(
                title: "Add Job Details",
                description: "Open a job to add **notes**, **materials**, and **assignment**. Assignment format accepts 54, 54.1, or 1.2.3 (up to 3 groups).",
                imageName: "note.text"
            )

            TutorialPage(
                title: "Smart Sorting",
                description: "Enable **Smart Routing** in Settings to automatically sort jobs by closest-first (or farthest-first).",
                imageName: "location"
            )

            TutorialPage(
                title: "Time Sheets",
                description: "Any job not **Pending** automatically appears on your **Time Sheet** and **Yellow Sheet**.",
                imageName: "clock"
            )

            TutorialPage(
                title: "Share Your Day",
                description: "Use the **Share** button on the dashboard to send today’s jobs by text — it includes your notes and photos.",
                imageName: "square.and.arrow.up"
            )

            TutorialPage(
                title: "Route Mapper (Private Sessions)",
                description: "Start a private session and **invite a coworker** to view updates in real time. Only invited users can see the route.",
                imageName: "person.2.fill"
            )

            TutorialPage(
                title: "Map Controls",
                description: "Tap the **locate** button to jump to you. Use the **satellite** map for imagery. Tap the map to drop poles; long‑press to insert between spans.",
                imageName: "location.circle.fill"
            )

            // Choice page: Apple vs Google suggestions
            TutorialChoicePage(
                title: "Address Suggestions",
                description: "Choose your preferred provider for address lookups. You can change this anytime in **Settings → Maps & Addresses**.",
                imageName: "mappin.circle",
                selection: $suggestionProviderRaw
            )

            // Final Page with "Get Started"
            VStack {
                Spacer()
                Text("You're Ready to Go!")
                    .font(.title)
                    .bold()
                Text("Start tracking your jobs now.")
                    .padding()
                Spacer()
                Button(action: { hasSeenTutorial = true }) {
                    Text("Get Started")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
    }
}

struct TutorialPage: View {
    var title: String
    var description: String
    var imageName: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                Text(title)
                    .font(.title)
                    .bold()
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
    }
}

struct TutorialChoicePage: View {
    var title: String
    var description: String
    var imageName: String
    @Binding var selection: String // "apple" or "google"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                Text(title)
                    .font(.title)
                    .bold()
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Picker("Address Suggestions", selection: $selection) {
                    Text("Apple (Default)").tag("apple")
                    Text("Google (Beta)").tag("google")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 30)

                Text(selection == "google" ? "Google suggestions are in testing. You can switch back anytime in Settings." : "Apple Maps suggestions are active. You can switch anytime in Settings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 30)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
    }
}

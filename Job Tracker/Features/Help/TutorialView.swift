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
                title: "Welcome to Job Tracker",
                description: """
- Use the segmented control at the top to choose **Sign In**, **Sign Up**, or **Reset** for your account task.
- Enter your credentials in the selected form and submit to reach the **Jobs** dashboard.
- Anytime you need a refresher, tap **Preview the onboarding tutorial** under the forms.
""",
                imageName: "sparkles"
            )

            TutorialPage(
                title: "Create Jobs the Right Way",
                description: """
- From **Jobs**, tap **Create Job** to open the new job form.
- Fill **Enter address**, adjust **Select Date**, and pick a status from the **Status** menu before saving.
- Enter the required number in **Job Number \***; CAN roles should add dotted codes in **Assignments** using the provided formatter.
- Capture context with **Materials Used** and **Notes**, then hit **Save Job**. After saving, open the job and use **Add Photo** under **New Photos** to attach images.
""",
                imageName: "plus.circle.fill"
            )

            TutorialPage(
                title: "Own Your Dashboard",
                description: """
- Switch days with the weekday capsules above the list or tap the **calendar** button in the Jobs header to jump to another date.
- Tap any job card to open details, or press its **Status** chip to move between Pending, Needs Aerial, Done, or **Custom…**.
- Use the **map** button for directions, the **square.and.arrow.up** share icon, or swipe for the contextual **Directions**, **Share**, and **Delete** menu.
""",
                imageName: "calendar"
            )

            TutorialPage(
                title: "Search & Update Details",
                description: """
- Open **Search Jobs** and type in the **Address, #, status, user…** field to search across your crew.
- Tap a result card to open **Job Detail**; adjust the **Status** menu, update the **Materials —** section, and expand **Notes** as needed.
- Scroll to **Existing Photos** to review attachments, then tap **Add Photo** in **New Photos** and use **Save** in the navigation bar to commit your edits.
""",
                imageName: "magnifyingglass.circle.fill"
            )

            TutorialPage(
                title: "Weekly Timesheet & Yellow Sheet",
                description: """
- Open **Timesheets** and use the **Week of …** button or the chevrons to pick the correct week.
- Enter crew info with **Supervisor** and **Add Name**, then fill each worker's Gibson and CS hours; tap day cards to adjust totals per job.
- Switch to **Yellow Sheet**, reuse the **Week of …** picker to review grouped jobs, and tap **Save Yellow Sheet** when everything matches.
""",
                imageName: "clock.badge.checkmark"
            )

            TutorialPage(
                title: "Route Mapper Essentials",
                description: """
- In **Route Mapper**, start with the **Search address** bar; choosing a suggestion zooms in and drops your next pole.
- Tap the map to add poles or long-press between spans to insert; use the markup palette to switch drawing tools.
- Host live work by tapping **Start Session** or join with **Join**; share the code with the invite button (person+ icon), recenter with **location.fill**, and export using **square.and.arrow.up**.
""",
                imageName: "map"
            )

            TutorialPage(
                title: "Partner Coordination",
                description: """
- Visit **Find a Partner** to review your current partner and use **Unpair** when you need to disconnect.
- Respond to crew invites with **Approve** or **Decline** inside **Incoming Requests**, and monitor pending outreach under **Outgoing Requests**.
- Browse the roster in **Find a Partner** and tap **Request** beside a teammate to send a new invite; the row will update to **Requested** once sent.
""",
                imageName: "person.2.fill"
            )

            TutorialPage(
                title: "Settings & Support",
                description: """
- Open **Settings** to customize the app for your crew.
- Toggle **Enable Smart Routing** and choose an **Optimize By** option to sort your day automatically.
- Adjust the **Address Suggestions** picker, review your account card, and tap **Contact Support** whenever you need help.
""",
                imageName: "gearshape.2.fill"
            )

            TutorialPage(
                title: "Address Suggestions Overview",
                description: """
- Job entry uses live lookups powered by Apple Maps by default; switching to Google (Beta) can surface harder-to-find addresses.
- Pick the provider that fits your territory now—you can always change it later in **Settings → Maps & Addresses → Address Suggestions**.
""",
                imageName: "map.circle"
            )

            // Choice page: Apple vs Google suggestions
            TutorialChoicePage(
                title: "Address Suggestions",
                description: "Choose your preferred provider for address lookups. You can change this anytime in **Settings → Maps & Addresses → Address Suggestions**.",
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

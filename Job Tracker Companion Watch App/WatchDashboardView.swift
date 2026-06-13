//
//  WatchDashboardView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//


// Watch App target → WatchDashboardView.swift

import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var jobsVM: WatchJobsViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            if jobsVM.todaysJobs.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .imageScale(.large)
                            .padding(.top, 8)
                        Text("No jobs for today")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Section("Today") {
                    ForEach(jobsVM.todaysJobs) { job in
                        NavigationLink(value: job) {
                            JobRow(job: job)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                openDirections(job.address)
                            } label: {
                                Label("Directions", systemImage: "map")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Jobs")
        .navigationDestination(for: WatchJob.self) { job in
            WatchJobDetailView(job: job)
        }
    }

    private func openDirections(_ address: String) {
        let q = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "http://maps.apple.com/?q=\(q)") {
            openURL(url)
        }
    }
}

// Replace the body of JobRow with this:
private struct JobRow: View {
    let job: WatchJob
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Address first (primary)
            Text(job.address)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.tail)

            // Job number second (secondary)
            if let num = job.jobNumber, !num.isEmpty {
                Text(num)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if let s = job.status, !s.isEmpty {
                Text(s)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(.blue.opacity(0.2)))
            }
        }
    }
}

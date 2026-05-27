//
//  WatchJobDetailView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//


// Watch App target → WatchJobDetailView.swift

import SwiftUI

struct WatchJobDetailView: View {
    @EnvironmentObject private var bridge: WatchBridge
    @EnvironmentObject private var jobsVM: WatchJobsViewModel
    @Environment(\.openURL) private var openURL

    let job: WatchJob
    @State private var status: String = ""
    @State private var customStatus: String = ""

    private let statuses = [
        "Pending",
        "Needs Ariel",
        "Needs Underground",
        "Needs Nid",
        "Needs Can",
        "Done",
        "Talk to Rick",
        "Custom"
    ]

    var body: some View {
        List {
            // In the first Section, replace the VStack with:
            VStack(alignment: .leading, spacing: 6) {
                Text(job.address)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let num = job.jobNumber, !num.isEmpty {
                    Text(num)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(statuses, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                .pickerStyle(.navigationLink)
                
                if status == "Custom" {
                    TextField("Custom status", text: $customStatus)
                        .textInputAutocapitalization(.never)
                }
                
                Button("Save Status") {
                    let trimmed = customStatus.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalStatus = (status == "Custom") ? (trimmed.isEmpty ? "Custom" : trimmed) : status
                    jobsVM.updateStatus(job: job, to: finalStatus, via: bridge)
                }
            }

            Section {
                Button {
                    launchDirections(to: job.address)
                } label: {
                    Label("Directions", systemImage: "map")
                }
            }
        }
        .navigationTitle("Details")
        .onAppear {
            let s = job.status ?? "Pending"
            if statuses.contains(s) {
                status = s
                customStatus = ""
            } else {
                status = "Custom"
                customStatus = s
            }
        }
    }

    private func launchDirections(to address: String) {
        // Use Apple Maps; system will open Maps on watch
        let q = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "http://maps.apple.com/?q=\(q)") {
            openURL(url)
        }
    }
}

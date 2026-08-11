import SwiftUI

struct ExtraWorkView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel
    
    @State private var selectedJob: Job? = nil
    
    // The statuses we consider "extra work"
    private let neededStatuses = [
        "Needs OH",
        "Needs Underground",
        "Needs Nid",
        "Needs Can"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching Dashboard/CreateJobView.
                JTGradients.background(stops: 4)
                .edgesIgnoringSafeArea(.all)

                List {
                    ForEach(neededStatuses, id: \.self) { needed in
                        Section(header: Text(needed)
                                    .foregroundColor(JTColors.textPrimary)
                                    .font(.headline)) {
                            let matchingJobs = unclaimedJobs(status: needed)

                            if matchingJobs.isEmpty {
                                Text("No jobs")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(matchingJobs) { job in
                                    Button {
                                        selectedJob = job
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(job.address)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Created by: \(creatorFullName(for: job))")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Extra work at \(job.address)")
                                    .accessibilityValue("Created by \(creatorFullName(for: job))")
                                    .accessibilityHint("Opens job details")
                                    .accessibilityIdentifier("extraWork.job.\(job.id)")
                                }
                            }
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                // (iOS 26+): Remove the default list background.
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Extra Work")
            .jtNavigationBarStyle()
            .sheet(item: $selectedJob) { job in
                if let jobBinding = binding(for: job) {
                    JobDetailView(job: jobBinding)
                } else {
                    Text("Job not found.")
                }
            }
        }
    }

    private func binding(for selectedJob: Job) -> Binding<Job>? {
        let jobID = selectedJob.id
        guard jobsViewModel.jobs.contains(where: { $0.id == jobID }) else { return nil }

        return Binding(
            get: {
                jobsViewModel.jobs.first(where: { $0.id == jobID }) ?? selectedJob
            },
            set: { updatedJob in
                guard let index = jobsViewModel.jobs.firstIndex(where: { $0.id == jobID }) else { return }
                jobsViewModel.jobs[index] = updatedJob
            }
        )
    }

    private func unclaimedJobs(status: String) -> [Job] {
        jobsViewModel.jobs.filter { job in
            CrewPosition.statusDisplayName(from: job.status) == status && job.assignedTo == nil
        }
    }
    
    private func creatorFullName(for job: Job) -> String {
        guard let userId = job.createdBy else { return "Unknown" }
        if let user = usersViewModel.usersDict[userId] {
            return "\(user.firstName) \(user.lastName)"
        } else {
            return "Unknown"
        }
    }
}

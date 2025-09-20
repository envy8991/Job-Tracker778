import SwiftUI

struct ExtraWorkView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel
    
    @State private var selectedJob: Job? = nil
    
    // The statuses we consider "extra work"
    private let neededStatuses = [
        "Needs Ariel",
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
                                    VStack(alignment: .leading) {
                                        Text(job.address)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Created by: \(creatorFullName(for: job))")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedJob = job
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                // (iOS 16+): Remove the default list background.
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Extra Work")
            .sheet(item: $selectedJob) { job in
                if let index = jobsViewModel.jobs.firstIndex(where: { $0.id == job.id }) {
                    JobDetailView(job: $jobsViewModel.jobs[index])
                } else {
                    Text("Job not found.")
                }
            }
        }
    }
    
    private func unclaimedJobs(status: String) -> [Job] {
        jobsViewModel.jobs.filter { job in
            job.status == status && job.assignedTo == nil
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

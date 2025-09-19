//
//  JobSearchDetailView.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//


import SwiftUI

struct JobSearchDetailView: View {
    let job: Job
    @EnvironmentObject var usersViewModel: UsersViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                JTGradients.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: JTSpacing.lg) {
                        Text("Job Details")
                            .font(JTTypography.screenTitle)
                            .foregroundStyle(JTColors.textPrimary)
                            .padding(.top, JTSpacing.xl)
                            .padding(.horizontal, JTSpacing.lg)

                        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                                  strokeColor: JTColors.glassSoftStroke) {
                            VStack(alignment: .leading, spacing: JTSpacing.md) {
                                detailSection(title: "Address:", value: job.address)
                                detailSection(title: "Job Number:", value: job.jobNumber ?? "N/A")
                                detailSection(title: "Date:", value: DateFormatter.localizedString(from: job.date, dateStyle: .medium, timeStyle: .none))
                                detailSection(title: "Status:", value: job.status)

                                if let materials = job.materialsUsed, !materials.isEmpty {
                                    detailSection(title: "Materials:", value: materials)
                                }

                                if let can = job.canFootage, !can.isEmpty {
                                    detailSection(title: "CAN Footage:", value: can)
                                }
                                if let nid = job.nidFootage, !nid.isEmpty {
                                    detailSection(title: "NID Footage:", value: nid)
                                }

                                if let notes = job.notes, !notes.isEmpty {
                                    detailSection(title: "Notes:", value: notes)
                                }

                                if !job.photos.isEmpty {
                                    Text("Photos:")
                                        .font(JTTypography.headline)
                                        .foregroundStyle(JTColors.textPrimary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: JTSpacing.sm) {
                                            ForEach(job.photos, id: \.self) { urlString in
                                                PhotoThumbnail(urlString: urlString)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(JTSpacing.lg)
                        }
                        .padding(.horizontal, JTSpacing.lg)
                        .padding(.bottom, JTSpacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func detailSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            Text(title)
                .font(JTTypography.headline)
                .foregroundStyle(JTColors.textPrimary)
            Text(value)
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textSecondary)
        }
    }
}

private struct PhotoThumbnail: View {
    let urlString: String

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color.red
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Color.gray
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
    }
}

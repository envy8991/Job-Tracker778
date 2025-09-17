//
//  JobSearchDetailView.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//


import SwiftUI
import MapKit

struct JobSearchDetailView: View {
    let job: Job
    @EnvironmentObject var usersViewModel: UsersViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient.
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.17254902, green: 0.24313726, blue: 0.3137255, opacity: 1),
                        Color(red: 0.29803923, green: 0.6313726, blue: 0.6862745, opacity: 1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Job Details")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top, 40)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Group {
                                Text("Address:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(job.address)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            
                            Group {
                                Text("Job Number:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(job.jobNumber ?? "N/A")
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            
                            Group {
                                Text("Date:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(job.date, style: .date)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            
                            Group {
                                Text("Status:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(job.status)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            
                            if let materials = job.materialsUsed, !materials.isEmpty {
                                Group {
                                    Text("Materials:")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(materials)
                                        .font(.body)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Group {
                                if let can = job.canFootage, !can.isEmpty {
                                    Text("CAN Footage:")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(can)
                                        .font(.body)
                                        .foregroundColor(.white)
                                }
                                if let nid = job.nidFootage, !nid.isEmpty {
                                    Text("NID Footage:")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(nid)
                                        .font(.body)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            if let notes = job.notes, !notes.isEmpty {
                                Group {
                                    Text("Notes:")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(notes)
                                        .font(.body)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            if !job.photos.isEmpty {
                                Text("Photos:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(job.photos, id: \.self) { urlString in
                                            if let url = URL(string: urlString) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                            .frame(width: 100, height: 100)
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 100, height: 100)
                                                            .clipped()
                                                    case .failure:
                                                        Color.red.frame(width: 100, height: 100)
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            } else {
                                                Color.gray.frame(width: 100, height: 100)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                        .padding(.horizontal)
                        
                        Spacer()
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
}
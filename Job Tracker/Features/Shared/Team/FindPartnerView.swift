//
//  FindPartnerView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//

import SwiftUI
import FirebaseFirestore

struct FindPartnerView: View {
    @EnvironmentObject var usersViewModel: UsersViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var incoming: [PartnerRequest] = []
    @State private var outgoing: [PartnerRequest] = []
    @State private var partnerUid: String? = nil
    @State private var isLoading = false
    @State private var searchText: String = ""
    @State private var errorText: String? = nil
    @State private var cancellingRequestIDs: Set<String> = []
    @State private var incomingListener: ListenerRegistration? = nil
    @State private var outgoingListener: ListenerRegistration? = nil

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4)
                .ignoresSafeArea()

            List {
                // Current partner
                Section(header: Text("Current Partner")) {
                    if let pid = partnerUid, let p = usersViewModel.user(id: pid) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(p.firstName) \(p.lastName)")
                                    .font(.headline)
                                Text(p.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { unpair() } label: { Text("Unpair") }
                        }
                    } else {
                        Text("No partner selected")
                            .foregroundColor(.secondary)
                    }
                }

                // Incoming requests
                Section(header: Text("Incoming Requests")) {
                    if incoming.isEmpty {
                        Text("No incoming requests")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(incoming) { req in
                            if let u = usersViewModel.user(id: req.fromUid) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(u.firstName) \(u.lastName)")
                                        Text(u.email).font(.footnote).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Approve") { accept(req) }
                                    Button("Decline", role: .destructive) { decline(req) }
                                }
                            }
                        }
                    }
                }

                // Outgoing requests
                Section(header: Text("Outgoing Requests")) {
                    if outgoing.isEmpty {
                        Text("No pending requests")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(outgoing) { req in
                            if let u = usersViewModel.user(id: req.toUid) {
                                let isCancelling = req.id.map { cancellingRequestIDs.contains($0) } ?? false
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(u.firstName) \(u.lastName)")
                                        Text(u.email).font(.footnote).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        cancel(req)
                                    } label: {
                                        if isCancelling {
                                            ProgressView()
                                        } else {
                                            Text("Cancel")
                                        }
                                    }
                                    .disabled(isCancelling || req.id == nil)
                                }
                                .opacity(isCancelling ? 0.5 : 1.0)
                            }
                        }
                    }
                }

                // All users
                Section(header: Text("Find a Partner")) {
                    if visibleUsers.isEmpty {
                        Text(isSearchActive ? "No teammates match your search." : "No teammates available.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(visibleUsers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(user.firstName) \(user.lastName)")
                                    Text(user.email).font(.footnote).foregroundColor(.secondary)
                                }
                                Spacer()

                                if partnerUid == user.id {
                                    Label("Partnered", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if outgoing.contains(where: { $0.toUid == user.id }) {
                                    Text("Requested").foregroundColor(.secondary)
                                } else if incoming.contains(where: { $0.fromUid == user.id }) {
                                    Text("Requested you").foregroundColor(.secondary)
                                } else {
                                    Button("Request") { request(user.id) }
                                }
                            }
                        }
                    }
                }

                if let errorText = errorText {
                    Section {
                        Text(errorText)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: Text("Search teammates"))
            .padding(.top, 28) // spacing for hamburger overlay (iOS 16-safe)
        }
        .overlay(alignment: .center) {
            if isLoading { ProgressView().scaleEffect(1.2) }
        }
        .navigationTitle("Find a Partner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    private var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchActive: Bool { !trimmedSearchQuery.isEmpty }

    private var visibleUsers: [AppUser] {
        let me = authViewModel.currentUser?.id
        let base = usersViewModel.allUsers.filter { $0.id != me }
        guard isSearchActive else { return base }

        let loweredQuery = trimmedSearchQuery.lowercased()
        return base.filter { user in
            let fullName = "\(user.firstName) \(user.lastName)".lowercased()
            return fullName.contains(loweredQuery) || user.email.lowercased().contains(loweredQuery)
        }
    }

    // MARK: - Actions
    private func startListening() {
        stopListening()
        guard let uid = authViewModel.currentUser?.id else { return }
        updatePartnerId(showLoading: true)
        incomingListener = FirebaseService.shared.listenIncomingRequests(for: uid) { reqs in
            DispatchQueue.main.async { self.incoming = reqs }
        }
        outgoingListener = FirebaseService.shared.listenOutgoingRequests(for: uid) { reqs in
            DispatchQueue.main.async { self.outgoing = reqs }
        }
    }

    private func stopListening() {
        incomingListener?.remove()
        incomingListener = nil
        outgoingListener?.remove()
        outgoingListener = nil
    }

    private func updatePartnerId(showLoading: Bool) {
        guard let uid = authViewModel.currentUser?.id else { return }
        if showLoading {
            isLoading = true
        }
        FirebaseService.shared.fetchPartnerId(for: uid) { id in
            DispatchQueue.main.async {
                self.partnerUid = id
                if showLoading {
                    self.isLoading = false
                }
            }
        }
    }

    private func request(_ toUid: String) {
        guard let uid = authViewModel.currentUser?.id else { return }
        errorText = nil
        FirebaseService.shared.sendPartnerRequest(from: uid, to: toUid) { ok in
            if !ok { DispatchQueue.main.async { self.errorText = "Failed to send request." } }
        }
    }

    private func accept(_ req: PartnerRequest) {
        errorText = nil
        FirebaseService.shared.acceptPartnerRequest(request: req) { ok in
            DispatchQueue.main.async {
                if ok {
                    self.updatePartnerId(showLoading: false)
                } else {
                    self.errorText = "Failed to approve request."
                }
            }
        }
    }

    private func decline(_ req: PartnerRequest) {
        errorText = nil
        FirebaseService.shared.declinePartnerRequest(request: req) { ok in
            if !ok { DispatchQueue.main.async { self.errorText = "Failed to decline request." } }
        }
    }

    private func cancel(_ req: PartnerRequest) {
        guard let reqId = req.id else {
            errorText = "Unable to cancel request."
            return
        }
        errorText = nil
        cancellingRequestIDs.insert(reqId)
        FirebaseService.shared.cancelPartnerRequest(request: req) { ok in
            DispatchQueue.main.async {
                self.cancellingRequestIDs.remove(reqId)
                if ok {
                    self.outgoing.removeAll { $0.id == reqId }
                } else {
                    self.errorText = "Failed to cancel request."
                }
            }
        }
    }

    private func unpair() {
        guard let uid = authViewModel.currentUser?.id, let pid = partnerUid else { return }
        errorText = nil
        FirebaseService.shared.unpair(uid: uid, partnerUid: pid) { ok in
            DispatchQueue.main.async {
                if ok { self.partnerUid = nil } else { self.errorText = "Failed to unpair." }
            }
        }
    }
}

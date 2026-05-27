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
    @State private var pendingRequestUserIDs: Set<String> = []
    @State private var pendingAcceptRequestIDs: Set<String> = []
    @State private var pendingDeclineRequestIDs: Set<String> = []
    @State private var pendingCancelRequestIDs: Set<String> = []
    @State private var requestErrors: [String: String] = [:]
    @State private var incomingRequestErrors: [String: String] = [:]
    @State private var cancelErrors: [String: String] = [:]
    @State private var unpairError: String? = nil
    @State private var isUnpairing = false
    @State private var incomingListener: ListenerRegistration? = nil
    @State private var outgoingListener: ListenerRegistration? = nil
    @State private var partnerListener: ListenerRegistration? = nil

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4)
                .ignoresSafeArea()

            List {
                // Current partner
                Section(header: Text("Current Partner")) {
                    if let pid = partnerUid, let p = usersViewModel.user(id: pid) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(p.firstName) \(p.lastName)")
                                        .font(.headline)
                                    Text(p.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { unpair() } label: {
                                    if isUnpairing {
                                        ProgressView()
                                    } else {
                                        Text("Unpair")
                                    }
                                }
                                .disabled(isUnpairing)
                            }
                            if let message = unpairError {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
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
                                let key = requestKey(for: req)
                                let isAccepting = pendingAcceptRequestIDs.contains(key)
                                let isDeclining = pendingDeclineRequestIDs.contains(key)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(u.firstName) \(u.lastName)")
                                            Text(u.email)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            accept(req)
                                        } label: {
                                            if isAccepting {
                                                ProgressView()
                                            } else {
                                                Text("Approve")
                                            }
                                        }
                                        .disabled(isAccepting || isDeclining)
                                        Button(role: .destructive) {
                                            decline(req)
                                        } label: {
                                            if isDeclining {
                                                ProgressView()
                                            } else {
                                                Text("Decline")
                                            }
                                        }
                                        .disabled(isAccepting || isDeclining)
                                    }
                                    if let message = incomingRequestErrors[key] {
                                        Text(message)
                                            .font(.footnote)
                                            .foregroundColor(.red)
                                    }
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
                                let key = requestKey(for: req)
                                let isCancelling = pendingCancelRequestIDs.contains(key)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(u.firstName) \(u.lastName)")
                                            Text(u.email)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
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
                                    if let message = cancelErrors[key] {
                                        Text(message)
                                            .font(.footnote)
                                            .foregroundColor(.red)
                                    }
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
                            let isRequesting = pendingRequestUserIDs.contains(user.id)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(user.firstName) \(user.lastName)")
                                        Text(user.email)
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()

                                    if partnerUid == user.id {
                                        Label("Partnered", systemImage: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else if outgoing.contains(where: { $0.toUid == user.id }) {
                                        Text("Requested")
                                            .foregroundColor(.secondary)
                                    } else if incoming.contains(where: { $0.fromUid == user.id }) {
                                        Text("Requested you")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Button {
                                            request(user)
                                        } label: {
                                            if isRequesting {
                                                ProgressView()
                                            } else {
                                                Text("Request")
                                            }
                                        }
                                        .disabled(isRequesting)
                                    }
                                }
                                if let message = requestErrors[user.id] {
                                    Text(message)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                        }
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
        isLoading = true
        partnerListener = FirebaseService.shared.listenPartnerId(for: uid) { id in
            DispatchQueue.main.async {
                self.partnerUid = id
                self.isLoading = false
            }
        }
        incomingListener = FirebaseService.shared.listenIncomingRequests(for: uid) { reqs in
            DispatchQueue.main.async {
                self.incoming = reqs
                self.synchronizeIncomingState(with: reqs)
            }
        }
        outgoingListener = FirebaseService.shared.listenOutgoingRequests(for: uid) { reqs in
            DispatchQueue.main.async {
                self.outgoing = reqs
                self.synchronizeOutgoingState(with: reqs)
            }
        }
    }

    private func stopListening() {
        partnerListener?.remove()
        partnerListener = nil
        incomingListener?.remove()
        incomingListener = nil
        outgoingListener?.remove()
        outgoingListener = nil
    }

    private func request(_ user: AppUser) {
        guard let uid = authViewModel.currentUser?.id else { return }
        let toUid = user.id
        guard !pendingRequestUserIDs.contains(toUid) else { return }

        requestErrors[toUid] = nil
        pendingRequestUserIDs.insert(toUid)

        let displayName = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)

        FirebaseService.shared.sendPartnerRequest(from: uid, to: toUid) { ok in
            DispatchQueue.main.async {
                self.pendingRequestUserIDs.remove(toUid)
                if ok {
                    self.requestErrors[toUid] = nil
                } else {
                    let fallbackName = displayName.isEmpty ? "that teammate" : displayName
                    self.requestErrors[toUid] = "Couldn't send an invite to \(fallbackName)."
                }
            }
        }
    }

    private func accept(_ req: PartnerRequest) {
        let key = requestKey(for: req)
        guard !pendingAcceptRequestIDs.contains(key) else { return }

        incomingRequestErrors[key] = nil

        guard req.id != nil else {
            incomingRequestErrors[key] = "Missing information needed to approve this invite."
            return
        }

        pendingAcceptRequestIDs.insert(key)
        pendingDeclineRequestIDs.remove(key)

        let senderDisplayName = usersViewModel.user(id: req.fromUid).map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) }

        FirebaseService.shared.acceptPartnerRequest(request: req) { ok in
            DispatchQueue.main.async {
                self.pendingAcceptRequestIDs.remove(key)
                if ok {
                    self.incoming.removeAll { self.requestKey(for: $0) == key }
                    self.incomingRequestErrors[key] = nil
                    if let currentId = self.authViewModel.currentUser?.id {
                        self.partnerUid = currentId == req.fromUid ? req.toUid : req.fromUid
                    }
                } else {
                    let name = senderDisplayName?.isEmpty == false ? senderDisplayName! : "that invite"
                    self.incomingRequestErrors[key] = "Couldn't approve \(name)."
                }
            }
        }
    }

    private func decline(_ req: PartnerRequest) {
        let key = requestKey(for: req)
        guard !pendingDeclineRequestIDs.contains(key) else { return }

        incomingRequestErrors[key] = nil

        guard req.id != nil else {
            incomingRequestErrors[key] = "Missing information needed to decline this invite."
            return
        }

        pendingDeclineRequestIDs.insert(key)
        pendingAcceptRequestIDs.remove(key)

        let senderDisplayName = usersViewModel.user(id: req.fromUid).map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) }

        FirebaseService.shared.declinePartnerRequest(request: req) { ok in
            DispatchQueue.main.async {
                self.pendingDeclineRequestIDs.remove(key)
                if ok {
                    self.incoming.removeAll { self.requestKey(for: $0) == key }
                    self.incomingRequestErrors[key] = nil
                } else {
                    let name = senderDisplayName?.isEmpty == false ? senderDisplayName! : "that invite"
                    self.incomingRequestErrors[key] = "Couldn't decline \(name)."
                }
            }
        }
    }

    private func cancel(_ req: PartnerRequest) {
        let key = requestKey(for: req)
        guard !pendingCancelRequestIDs.contains(key) else { return }

        cancelErrors[key] = nil

        guard req.id != nil else {
            cancelErrors[key] = "Missing information needed to cancel this invite."
            return
        }

        pendingCancelRequestIDs.insert(key)

        let recipientDisplayName = usersViewModel.user(id: req.toUid).map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) }

        FirebaseService.shared.cancelPartnerRequest(request: req) { ok in
            DispatchQueue.main.async {
                self.pendingCancelRequestIDs.remove(key)
                if ok {
                    self.outgoing.removeAll { self.requestKey(for: $0) == key }
                    self.cancelErrors[key] = nil
                } else {
                    let name = recipientDisplayName?.isEmpty == false ? recipientDisplayName! : "that teammate"
                    self.cancelErrors[key] = "Couldn't cancel the invite to \(name)."
                }
            }
        }
    }

    private func unpair() {
        guard let uid = authViewModel.currentUser?.id,
              let pid = partnerUid,
              !isUnpairing else { return }

        unpairError = nil
        isUnpairing = true

        let partnerDisplayName = usersViewModel.user(id: pid).map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) }

        FirebaseService.shared.unpair(uid: uid, partnerUid: pid) { ok in
            DispatchQueue.main.async {
                self.isUnpairing = false
                if ok {
                    self.partnerUid = nil
                    self.unpairError = nil
                } else {
                    let name = partnerDisplayName?.isEmpty == false ? partnerDisplayName! : "your partner"
                    self.unpairError = "Couldn't unpair from \(name)."
                }
            }
        }
    }

    private func requestKey(for request: PartnerRequest) -> String {
        request.id ?? "\(request.fromUid)-\(request.toUid)"
    }

    private func synchronizeIncomingState(with requests: [PartnerRequest]) {
        let keys = Set(requests.map { requestKey(for: $0) })
        incomingRequestErrors = Dictionary(uniqueKeysWithValues: incomingRequestErrors.filter { keys.contains($0.key) })
        pendingAcceptRequestIDs = pendingAcceptRequestIDs.intersection(keys)
        pendingDeclineRequestIDs = pendingDeclineRequestIDs.intersection(keys)
    }

    private func synchronizeOutgoingState(with requests: [PartnerRequest]) {
        let keys = Set(requests.map { requestKey(for: $0) })
        cancelErrors = Dictionary(uniqueKeysWithValues: cancelErrors.filter { keys.contains($0.key) })
        pendingCancelRequestIDs = pendingCancelRequestIDs.intersection(keys)
    }
}

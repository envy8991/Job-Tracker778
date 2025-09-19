//
//  ChatView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 5/2/25.
//

//
//  ChatView.swift
//  Job Tracker
//
//  Two‑person chat screen with bubbles & send bar.
//

import SwiftUI

struct ChatView: View {
    let peer: AppUser                       // the person you’re chatting with
    @Binding var inChat: Bool
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var vm: ChatViewModel
    
    // Build a deterministic roomID from the two UIDs
    init(peer: AppUser, inChat: Binding<Bool>, currentUID: String? = nil) {
        self.peer = peer
        _inChat = inChat
        // For previews we can pass a dummy ID; otherwise fetch from FirebaseService
        let myID  = currentUID ?? FirebaseService.shared.currentUserID() ?? "unknown"
        let room  = [myID, peer.id].sorted().joined(separator: "_")
        _vm = StateObject(wrappedValue: ChatViewModel(roomID: room, currentUID: myID))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom in-app header that sits below your hamburger overlay
            headerBar

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.messages) { msg in
                            bubble(for: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            // Send bar pinned to bottom
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Message…", text: $vm.draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    Button {
                        vm.send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .imageScale(.large)
                            .foregroundColor(
                                vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .gray
                                : .accentColor
                            )
                    }
                    .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .toolbar(.hidden, for: .navigationBar) // Hide system nav bar so hamburger can't overlap the back button
        .gradientBackground()
        .onAppear { inChat = true }
        .onDisappear { inChat = false }
    }
    
    // MARK: – Custom header
    private var headerBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Messages")
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(peer.firstName)
                .font(.headline)
                .bold()

            Spacer()

            // Right side spacer to balance title centering
            Color.clear.frame(width: 44, height: 1)
        }
        .foregroundColor(.white)
        .padding(.top, 44) // push down further to clear hamburger overlay
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color.clear)
    }
    
    // MARK: – Chat bubble
    @ViewBuilder
    private func bubble(for msg: ChatMessage) -> some View {
        let isMe = msg.senderID == authVM.currentUser?.id
        HStack {
            if isMe { Spacer(minLength: 40) }
            Text(msg.text)
                .padding(10)
                .background(isMe ? Color.accentColor : Color.white.opacity(0.12))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 260, alignment: isMe ? .trailing : .leading)
            if !isMe { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 4)
    }
}

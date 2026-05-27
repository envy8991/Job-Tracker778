//
//  AppUser.swift
//  Job Tracker
//
//  Updated May 5 2025
//

import Foundation

/// Top‑level user document mapped from Firestore `users/{uid}`.
struct AppUser: Identifiable, Codable, Hashable {
    
    // MARK: Core fields
    /// Matches Firebase Auth UID
    var id: String
    
    var firstName: String
    var lastName:  String
    var email:     String
    /// "Ariel", "Underground", "Nid", or "Can"
    var position:  String
    /// Access flags
    var isAdmin: Bool      // platform admin (you)
    var isSupervisor: Bool // supervisors can view role-wide dashboards
    
    // MARK: Optional assets
    /// Remote avatar; if `nil` UI falls back to initials.
    var profilePictureURL: String?
    
    // MARK: Member‑wise init (fully defaultable)
    private enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, position, profilePictureURL, isAdmin, isSupervisor
    }

    init(
        id: String = UUID().uuidString,
        firstName: String,
        lastName: String,
        email: String,
        position: String,
        profilePictureURL: String? = nil,
        isAdmin: Bool = false,
        isSupervisor: Bool = false
    ) {
        self.id                = id
        self.firstName         = firstName
        self.lastName          = lastName
        self.email             = email
        self.position          = position
        self.profilePictureURL = profilePictureURL
        self.isAdmin = isAdmin
        self.isSupervisor = isSupervisor
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id                = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.firstName         = try c.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        self.lastName          = try c.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        self.email             = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.position          = try c.decodeIfPresent(String.self, forKey: .position) ?? ""
        self.profilePictureURL = try c.decodeIfPresent(String.self, forKey: .profilePictureURL)
        self.isAdmin           = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        self.isSupervisor      = try c.decodeIfPresent(Bool.self, forKey: .isSupervisor) ?? false
    }
}

// MARK: – Convenience helpers
extension AppUser {
    /// Two‑letter uppercase initials for fallback avatars.
    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init)  ?? ""
        return (f + l).uppercased()
    }
    /// Normalized role (fixes legacy "Ariel" -> "Aerial")
    var normalizedPosition: String {
        let trimmed = position.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare("Ariel") == .orderedSame { return "Aerial" }
        return trimmed
    }
}

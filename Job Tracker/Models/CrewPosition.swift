import Foundation

/// Shared crew-position normalization so legacy Aerial/Ariel/Arial values continue to work
/// while the app displays and saves the current OH label.
enum CrewPosition: String, CaseIterable, Identifiable, Hashable {
    case ug = "UG"
    case oh = "OH"
    case can = "Can"
    case nid = "Nid"

    var id: String { rawValue }
    var displayName: String { rawValue }

    static let signupOptions = [oh.displayName, "Underground", nid.displayName, can.displayName]
    static let supervisorDashboardOptions: [CrewPosition] = [.ug, .oh, .can, .nid]

    static func positionDisplayName(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return isOH(trimmed) ? oh.displayName : trimmed
    }

    static func normalizedKey(from rawValue: String?) -> String {
        guard let rawValue else { return "" }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = normalizedToken(trimmed)

        if ohAliases.contains(token) { return oh.rawValue }
        if token == "ug" || token == "underground" { return ug.rawValue }
        if token == "can" { return can.rawValue }
        if token == "nid" { return nid.rawValue }
        return trimmed
    }

    static func matches(_ rawValue: String?, _ position: CrewPosition) -> Bool {
        normalizedKey(from: rawValue).caseInsensitiveCompare(position.rawValue) == .orderedSame
    }

    static func normalizedStatusForSaving(_ rawStatus: String) -> String {
        let trimmed = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        if isOH(trimmed) { return oh.rawValue }
        if isNeedsOH(trimmed) { return "Needs OH" }
        return trimmed
    }

    static func statusDisplayName(from rawStatus: String) -> String {
        let trimmed = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        if isOH(trimmed) { return oh.rawValue }
        if isNeedsOH(trimmed) { return "Needs OH" }
        return trimmed
    }

    static func isOH(_ rawValue: String?) -> Bool {
        guard let rawValue else { return false }
        return ohAliases.contains(normalizedToken(rawValue))
    }

    private static func isNeedsOH(_ rawStatus: String) -> Bool {
        let token = normalizedToken(rawStatus)
        return token == "needsoh" || token == "needsaerial" || token == "needsariel" || token == "needsarial" || token == "needsoverhead"
    }

    private static let ohAliases: Set<String> = ["oh", "overhead", "aerial", "ariel", "arial"]

    private static func normalizedToken(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

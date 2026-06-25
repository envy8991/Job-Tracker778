import Foundation

struct AddressDuplicateMatcher {
    struct Comparison {
        let isExact: Bool
        let isClose: Bool
    }

    private struct Components {
        let normalizedKey: String
        let streetNumber: String?
        let streetTokens: [String]
        let unit: String?
    }

    private static let replacements: [String: String] = [
        "street": "st",
        "st.": "st",
        "avenue": "ave",
        "ave.": "ave",
        "road": "rd",
        "rd.": "rd",
        "drive": "dr",
        "dr.": "dr",
        "lane": "ln",
        "ln.": "ln",
        "court": "ct",
        "ct.": "ct",
        "highway": "hwy",
        "hwy.": "hwy",
        "apartment": "apt",
        "apt.": "apt",
        "unit": "apt",
        "suite": "ste",
        "ste.": "ste",
        "#": "apt"
    ]

    static func compare(_ lhs: String, _ rhs: String) -> Comparison {
        let lhsComponents = components(from: lhs)
        let rhsComponents = components(from: rhs)
        guard !lhsComponents.normalizedKey.isEmpty, !rhsComponents.normalizedKey.isEmpty else {
            return Comparison(isExact: false, isClose: false)
        }

        if lhsComponents.normalizedKey == rhsComponents.normalizedKey {
            return Comparison(isExact: true, isClose: false)
        }

        if let lhsNumber = lhsComponents.streetNumber, let rhsNumber = rhsComponents.streetNumber, lhsNumber != rhsNumber {
            return Comparison(isExact: false, isClose: false)
        }

        if let lhsUnit = lhsComponents.unit, let rhsUnit = rhsComponents.unit, lhsUnit != rhsUnit {
            return Comparison(isExact: false, isClose: false)
        }

        let lhsTokens = Set(lhsComponents.streetTokens)
        let rhsTokens = Set(rhsComponents.streetTokens)
        let shared = lhsTokens.intersection(rhsTokens).count
        let smallest = min(lhsTokens.count, rhsTokens.count)
        let streetNameIsClose = smallest >= 2 && shared >= max(2, smallest - 1)

        return Comparison(isExact: false, isClose: streetNameIsClose)
    }

    static func normalizedAddressKey(_ rawValue: String) -> String {
        normalizedTokens(from: rawValue).joined(separator: " ")
    }

    private static func components(from rawValue: String) -> Components {
        let tokens = normalizedTokens(from: rawValue)
        let unit = unitIdentifier(from: tokens)
        let streetNumber = tokens.first(where: { $0.allSatisfy(\.isNumber) })
        let streetTokens = tokens.filter { token in
            if token == streetNumber { return false }
            if let unit, token == unit { return false }
            return !unitMarkers.contains(token)
        }

        return Components(
            normalizedKey: tokens.joined(separator: " "),
            streetNumber: streetNumber,
            streetTokens: streetTokens,
            unit: unit
        )
    }

    private static func normalizedTokens(from rawValue: String) -> [String] {
        rawValue
            .lowercased()
            .replacingOccurrences(of: "#", with: " apt ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { replacements[$0] ?? $0 }
    }

    private static let unitMarkers = Set(["apt", "ste", "lot", "space", "bldg", "building", "trailer"])

    private static func unitIdentifier(from tokens: [String]) -> String? {
        for (index, token) in tokens.enumerated() where unitMarkers.contains(token) {
            let nextIndex = index + 1
            if tokens.indices.contains(nextIndex) {
                return tokens[nextIndex]
            }
        }
        return nil
    }
}

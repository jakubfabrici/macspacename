import Foundation

/// Ranks spaces for the Quick Switcher. Higher score = better match. `nil` = no match.
///
/// Diacritics and case are ignored, so "praca" finds "Práca".
public enum SpaceMatcher {
    public static func normalize(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func score(query: String, candidate: String) -> Int? {
        let q = normalize(query)
        let c = normalize(candidate)
        if q.isEmpty { return 0 }
        if c.isEmpty { return nil }
        if c == q { return 1000 }
        if c.hasPrefix(q) { return 800 - min(c.count - q.count, 100) }
        let words = c.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" || $0 == "/" })
        if words.contains(where: { $0.hasPrefix(q) }) { return 600 }
        if c.contains(q) { return 400 }
        return subsequenceScore(query: q, candidate: c)
    }

    /// Fuzzy "subsequence" match: every query character appears in order. Rewards compact matches.
    static func subsequenceScore(query: String, candidate: String) -> Int? {
        var remaining = Substring(query)
        var firstIndex: Int?
        var lastIndex = 0
        for (index, char) in candidate.enumerated() {
            guard let next = remaining.first else { break }
            if char == next {
                if firstIndex == nil { firstIndex = index }
                lastIndex = index
                remaining = remaining.dropFirst()
            }
        }
        guard remaining.isEmpty, let first = firstIndex else { return nil }
        let span = lastIndex - first + 1
        let compactness = max(0, 100 - (span - query.count) * 10)
        return 100 + compactness
    }
}

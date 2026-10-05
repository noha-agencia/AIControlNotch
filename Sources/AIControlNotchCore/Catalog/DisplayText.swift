import Foundation

/// Rules for short text that comes from outside (`providers.json`, script output) and is
/// drawn in the notch: something visible, nothing that reorders the line, bounded size.
enum DisplayText {
    /// Combining marks can stack on one character; this caps them all.
    static let maxScalars = 48
    /// Marks drawn on one character. Vietnamese needs two, Thai three; Zalgo text needs many.
    static let maxMarksPerCharacter = 4
    static let echoLength = 32
    /// Control, format (bidi overrides, zero-width spaces), line and paragraph separators,
    /// private-use and unassigned code points.
    static let forbidden: Set<Unicode.GeneralCategory> = [
        .control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .unassigned,
    ]
    static let marks: Set<Unicode.GeneralCategory> = [.nonspacingMark, .enclosingMark]
    /// Zero-width joiners hold emoji sequences and some scripts together.
    static let joiners: Set<Unicode.Scalar> = ["\u{200C}", "\u{200D}"]
    /// Draws nothing, yet is neither whitespace nor default-ignorable.
    static let blanks: Set<Unicode.Scalar> = ["\u{2800}"]

    /// The trimmed text, or `nil` when it breaks a rule. Blank text passes as "".
    static func clean(_ raw: String, maxCharacters: Int) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }
        guard text.count <= maxCharacters, text.unicodeScalars.count <= maxScalars,
              !text.unicodeScalars.contains(where: isForbidden),
              text.unicodeScalars.contains(where: isVisible),
              text.allSatisfy({ $0.unicodeScalars.count(where: isMark) <= maxMarksPerCharacter }) else { return nil }
        return text
    }

    /// A value safe to quote in an error message: visible characters only, shortened.
    static func echo(_ raw: String) -> String {
        let scalars = raw.unicodeScalars.filter { !isForbidden($0) }
        let visible = String(String.UnicodeScalarView(scalars.prefix(maxScalars)))
        let shortened = visible.count > echoLength || scalars.count > maxScalars
        return shortened ? String(visible.prefix(echoLength)) + "…" : visible
    }

    private static func isForbidden(_ scalar: Unicode.Scalar) -> Bool {
        forbidden.contains(scalar.properties.generalCategory) && !joiners.contains(scalar)
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        marks.contains(scalar.properties.generalCategory)
    }

    /// Hangul fillers and variation selectors are default-ignorable; marks need a base.
    private static func isVisible(_ scalar: Unicode.Scalar) -> Bool {
        let properties = scalar.properties
        return !properties.isWhitespace && !properties.isDefaultIgnorableCodePoint && !isMark(scalar) && !blanks.contains(scalar)
    }
}

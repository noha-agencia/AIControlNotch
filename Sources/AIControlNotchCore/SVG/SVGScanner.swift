import CoreGraphics
import Foundation

/// Reads the tokens of SVG path data: command letters, numbers and arc flags.
struct SVGScanner {
    private static let separators: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D, 0x2C]
    private static let commandLetters = Set("MmLlHhVvCcSsQqTtAaZz".utf8)

    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ text: String) {
        bytes = Array(text.utf8)
    }

    var isAtEnd: Bool {
        mutating get {
            skipSeparators()
            return offset >= bytes.count
        }
    }

    /// True when the next token is a number (an implicit repeat of the last command).
    mutating func hasNumber() -> Bool {
        skipSeparators()
        guard let byte = peek() else { return false }
        return Self.isDigit(byte) || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+")
    }

    mutating func command() throws -> Character {
        skipSeparators()
        guard let byte = peek(), Self.commandLetters.contains(byte) else {
            throw SVGPath.ParseError.unexpected(offset: offset)
        }
        offset += 1
        return Character(UnicodeScalar(byte))
    }

    mutating func peekCommand() -> Character? {
        skipSeparators()
        guard let byte = peek(), Self.commandLetters.contains(byte) else { return nil }
        return Character(UnicodeScalar(byte))
    }

    mutating func number() throws -> CGFloat {
        skipSeparators()
        let start = offset
        consumeSign()
        let integerDigits = consumeDigits()
        var fractionDigits = 0
        if peek() == UInt8(ascii: ".") {
            offset += 1
            fractionDigits = consumeDigits()
        }
        guard integerDigits + fractionDigits > 0 else {
            offset = start
            throw SVGPath.ParseError.missingNumber(offset: start)
        }
        consumeExponent()
        let text = String(decoding: bytes[start..<offset], as: UTF8.self)
        guard let value = Double(text) else { throw SVGPath.ParseError.missingNumber(offset: start) }
        return CGFloat(value)
    }

    /// Arc flags are a single "0" or "1" and may touch the next number ("01 1 1").
    mutating func flag() throws -> Bool {
        skipSeparators()
        switch peek() {
        case UInt8(ascii: "0"): offset += 1; return false
        case UInt8(ascii: "1"): offset += 1; return true
        default: throw SVGPath.ParseError.missingNumber(offset: offset)
        }
    }

    private func peek(_ ahead: Int = 0) -> UInt8? {
        offset + ahead < bytes.count ? bytes[offset + ahead] : nil
    }

    private mutating func skipSeparators() {
        while let byte = peek(), Self.separators.contains(byte) { offset += 1 }
    }

    private mutating func consumeSign() {
        if peek() == UInt8(ascii: "-") || peek() == UInt8(ascii: "+") { offset += 1 }
    }

    private mutating func consumeDigits() -> Int {
        let start = offset
        while let byte = peek(), Self.isDigit(byte) { offset += 1 }
        return offset - start
    }

    private mutating func consumeExponent() {
        guard peek() == UInt8(ascii: "e") || peek() == UInt8(ascii: "E") else { return }
        let signed = peek(1) == UInt8(ascii: "-") || peek(1) == UInt8(ascii: "+")
        guard let digit = peek(signed ? 2 : 1), Self.isDigit(digit) else { return }
        offset += signed ? 2 : 1
        _ = consumeDigits()
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
    }
}

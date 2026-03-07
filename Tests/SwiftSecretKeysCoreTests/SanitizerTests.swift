import Testing
@testable import SwiftSecretKeysCore

@Suite("Sanitizer")
struct SanitizerTests {

    @Test("passesThroughValidIdentifier: valid camelCase identifier is unchanged")
    func passesThroughValidIdentifier() throws {
        let result = try Sanitizer.sanitize(keyNames: ["apiKey"])
        #expect(result["apiKey"] == "apiKey")
    }

    @Test("replacesHyphensWithUnderscore: hyphens become underscores")
    func replacesHyphensWithUnderscore() throws {
        let result = try Sanitizer.sanitize(keyNames: ["api-key"])
        #expect(result["api-key"] == "api_key")
    }

    @Test("prependsKeyToLeadingDigit: names starting with digit get key_ prefix")
    func prependsKeyToLeadingDigit() throws {
        let result = try Sanitizer.sanitize(keyNames: ["2fast"])
        #expect(result["2fast"] == "key_2fast")
    }

    @Test("escapesSwiftKeyword: Swift reserved keywords get backtick-escaped")
    func escapesSwiftKeyword() throws {
        let result = try Sanitizer.sanitize(keyNames: ["class"])
        #expect(result["class"] == "`class`")
    }

    @Test("collapsesConsecutiveUnderscores: double underscores collapse to single")
    func collapsesConsecutiveUnderscores() throws {
        // "a__b" contains consecutive underscores — should collapse
        let result = try Sanitizer.sanitize(keyNames: ["a__b"])
        #expect(result["a__b"] == "a_b")
    }

    @Test("trimsLeadingTrailingUnderscores: leading and trailing underscores are removed")
    func trimsLeadingTrailingUnderscores() throws {
        let result = try Sanitizer.sanitize(keyNames: ["_test_"])
        #expect(result["_test_"] == "test")
    }

    @Test("throwsOnEmptyName: empty string throws invalidKeyName")
    func throwsOnEmptyName() throws {
        #expect(throws: SSKeysError.invalidKeyName(original: "")) {
            try Sanitizer.sanitize(keyNames: [""])
        }
    }

    @Test("throwsOnSpecialCharsOnlyName: all-special-char name throws invalidKeyName")
    func throwsOnSpecialCharsOnlyName() throws {
        // "---" sanitizes to "___" which trims to "" — invalid
        #expect(throws: SSKeysError.invalidKeyName(original: "---")) {
            try Sanitizer.sanitize(keyNames: ["---"])
        }
    }

    @Test("throwsOnCollision: two names sanitizing to same identifier throws keyNameCollision")
    func throwsOnCollision() throws {
        // "a-b" -> "a_b" and "a_b" -> "a_b" — collision
        #expect(throws: (any Error).self) {
            try Sanitizer.sanitize(keyNames: ["a-b", "a_b"])
        }
    }

    @Test("handlesMultipleKeysCorrectly: multiple valid keys produce correct mappings")
    func handlesMultipleKeysCorrectly() throws {
        let keys = ["api-key", "DB_HOST", "serverPort"]
        let result = try Sanitizer.sanitize(keyNames: keys)
        #expect(result.count == 3)
        #expect(result["api-key"] == "api_key")
        #expect(result["DB_HOST"] == "DB_HOST")
        #expect(result["serverPort"] == "serverPort")
    }
}

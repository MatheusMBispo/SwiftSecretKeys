import Testing
@testable import SwiftSecretKeysCore

@Suite("DotEnvLoader")
struct DotEnvLoaderTests {

    // MARK: - Basic Parsing

    @Test("basic key=value parsing")
    func basicKeyValue() {
        let result = DotEnvLoader.parse("FOO=bar")
        #expect(result.count == 1)
        #expect(result[0].key == "FOO")
        #expect(result[0].value == "bar")
    }

    @Test("multiple key=value pairs")
    func multipleKeyValues() {
        let input = """
        FOO=bar
        BAZ=qux
        HELLO=world
        """
        let result = DotEnvLoader.parse(input)
        #expect(result.count == 3)
        #expect(result[0].key == "FOO")
        #expect(result[0].value == "bar")
        #expect(result[1].key == "BAZ")
        #expect(result[1].value == "qux")
        #expect(result[2].key == "HELLO")
        #expect(result[2].value == "world")
    }

    @Test("value with multiple equals signs preserves everything after first =")
    func multipleEqualsSigns() {
        let result = DotEnvLoader.parse("DATABASE_URL=postgres://user:pass@host/db?opt=val")
        #expect(result.count == 1)
        #expect(result[0].key == "DATABASE_URL")
        #expect(result[0].value == "postgres://user:pass@host/db?opt=val")
    }

    @Test("empty value")
    func emptyValue() {
        let result = DotEnvLoader.parse("EMPTY=")
        #expect(result.count == 1)
        #expect(result[0].key == "EMPTY")
        #expect(result[0].value == "")
    }

    // MARK: - Whitespace Handling

    @Test("trims whitespace around key and value")
    func whitespaceAroundKeyAndValue() {
        let result = DotEnvLoader.parse("  FOO  =  bar  ")
        #expect(result.count == 1)
        #expect(result[0].key == "FOO")
        #expect(result[0].value == "bar")
    }

    @Test("trims leading whitespace on line")
    func leadingWhitespaceOnLine() {
        let result = DotEnvLoader.parse("    API_KEY=secret123")
        #expect(result.count == 1)
        #expect(result[0].key == "API_KEY")
        #expect(result[0].value == "secret123")
    }

    // MARK: - Quoted Values

    @Test("double-quoted value strips quotes")
    func doubleQuotedValue() {
        let result = DotEnvLoader.parse("FOO=\"hello world\"")
        #expect(result.count == 1)
        #expect(result[0].value == "hello world")
    }

    @Test("single-quoted value strips quotes")
    func singleQuotedValue() {
        let result = DotEnvLoader.parse("FOO='hello world'")
        #expect(result.count == 1)
        #expect(result[0].value == "hello world")
    }

    @Test("double-quoted value preserves inner hash")
    func doubleQuotedPreservesHash() {
        let result = DotEnvLoader.parse("FOO=\"bar # not a comment\"")
        #expect(result.count == 1)
        #expect(result[0].value == "bar # not a comment")
    }

    @Test("single-quoted value preserves inner hash")
    func singleQuotedPreservesHash() {
        let result = DotEnvLoader.parse("FOO='bar # not a comment'")
        #expect(result.count == 1)
        #expect(result[0].value == "bar # not a comment")
    }

    @Test("double-quoted value with trailing comment strips comment")
    func doubleQuotedWithTrailingComment() {
        let result = DotEnvLoader.parse("FOO=\"bar\" # this is a comment")
        #expect(result.count == 1)
        #expect(result[0].value == "bar")
    }

    @Test("empty double-quoted value")
    func emptyDoubleQuoted() {
        let result = DotEnvLoader.parse("FOO=\"\"")
        #expect(result.count == 1)
        #expect(result[0].value == "")
    }

    @Test("empty single-quoted value")
    func emptySingleQuoted() {
        let result = DotEnvLoader.parse("FOO=''")
        #expect(result.count == 1)
        #expect(result[0].value == "")
    }

    // MARK: - Export Prefix

    @Test("strips export prefix")
    func exportPrefix() {
        let result = DotEnvLoader.parse("export FOO=bar")
        #expect(result.count == 1)
        #expect(result[0].key == "FOO")
        #expect(result[0].value == "bar")
    }

    @Test("export with extra whitespace")
    func exportExtraWhitespace() {
        let result = DotEnvLoader.parse("export   FOO=bar")
        #expect(result.count == 1)
        #expect(result[0].key == "FOO")
        #expect(result[0].value == "bar")
    }

    @Test("export with quoted value")
    func exportWithQuotedValue() {
        let result = DotEnvLoader.parse("export SECRET=\"my secret\"")
        #expect(result.count == 1)
        #expect(result[0].key == "SECRET")
        #expect(result[0].value == "my secret")
    }

    @Test("exportFOO without space is treated as key name, not prefix")
    func exportWithoutSpaceIsKeyName() {
        let result = DotEnvLoader.parse("exportFOO=bar")
        #expect(result.count == 1)
        #expect(result[0].key == "exportFOO")
        #expect(result[0].value == "bar")
    }

    // MARK: - Inline Comments

    @Test("strips inline comment from unquoted value")
    func inlineComment() {
        let result = DotEnvLoader.parse("FOO=bar # this is a comment")
        #expect(result.count == 1)
        #expect(result[0].value == "bar")
    }

    @Test("hash without preceding space is kept in value")
    func hashWithoutSpace() {
        let result = DotEnvLoader.parse("COLOR=#FF0000")
        #expect(result.count == 1)
        #expect(result[0].value == "#FF0000")
    }

    // MARK: - Comments and Blank Lines

    @Test("skips comment-only lines")
    func commentOnlyLines() {
        let input = """
        # This is a comment
        FOO=bar
        # Another comment
        """
        let result = DotEnvLoader.parse(input)
        #expect(result.count == 1)
        #expect(result[0].key == "FOO")
    }

    @Test("skips blank lines")
    func blankLines() {
        let input = """
        FOO=bar

        BAZ=qux

        """
        let result = DotEnvLoader.parse(input)
        #expect(result.count == 2)
    }

    @Test("skips lines without equals sign")
    func linesWithoutEquals() {
        let input = """
        FOO=bar
        this line has no equals
        BAZ=qux
        """
        let result = DotEnvLoader.parse(input)
        #expect(result.count == 2)
    }

    @Test("skips line with empty key")
    func emptyKeySkipped() {
        let result = DotEnvLoader.parse("=value")
        #expect(result.count == 0)
    }

    // MARK: - File Loading

    @Test("load throws on nonexistent file")
    func loadThrowsOnMissingFile() {
        #expect(throws: SSKeysError.self) {
            try DotEnvLoader.load(from: "/nonexistent/.env")
        }
    }
}

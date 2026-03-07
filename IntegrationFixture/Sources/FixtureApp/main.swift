import Foundation

let value = SecretKeys.FIXTURE_KEY
guard value == "integration-test-value" else {
    fatalError("Runtime decryption failed: expected 'integration-test-value', got '\(value)'")
}
print("IntegrationFixture: runtime decryption OK — FIXTURE_KEY resolved correctly")

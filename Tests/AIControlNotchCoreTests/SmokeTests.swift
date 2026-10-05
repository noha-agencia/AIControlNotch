import Testing
@testable import AIControlNotchCore

@Test func coreLoads() {
    #expect(ProviderDescriptor.claude.displayName == "Claude")
}

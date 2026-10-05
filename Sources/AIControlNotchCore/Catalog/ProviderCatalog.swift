import Foundation

/// The models shown, in order: pinned first, then the rest in configuration order.
public struct ProviderCatalog: Equatable, Sendable {
    public let descriptors: [ProviderDescriptor]
    /// Up to two models drawn on each side of the camera at rest.
    public let pinned: [ProviderID]

    public init(config: ProvidersConfig) {
        // The parser rejects repeated ids; a config built in code keeps the first.
        let scripts = Dictionary(config.scripts.map { ($0.id, ProviderDescriptor.script($0)) }, uniquingKeysWith: { first, _ in first })
        let ordered = config.pinned + config.enabledIDs.filter { !config.pinned.contains($0) }
        self.descriptors = ordered.map { scripts[$0] ?? ProviderDescriptor.builtIn($0) }
        self.pinned = config.pinned
    }

    public static let builtIn = ProviderCatalog(config: .default)

    public var ids: [ProviderID] { descriptors.map(\.id) }

    public func descriptor(_ id: ProviderID) -> ProviderDescriptor {
        descriptors.first { $0.id == id } ?? ProviderDescriptor.builtIn(id)
    }
}

import CoreGraphics
import Foundation
import AIControlNotchCore
import Observation

/// Everything the notch views read. Values are replaced, never edited in place.
@MainActor @Observable
final class NotchModel {
    private(set) var machine = NotchMachine()
    private(set) var snapshots: [ProviderID: ProviderSnapshot] = [:]
    private(set) var issues: [ProviderID: ProviderIssue] = [:]
    private(set) var now: Date
    /// Kept after the alert hides so the layer can fade out with its content.
    private(set) var alertContent: AlertContent?
    /// Bumped per alert so the ring view restarts its sweep.
    private(set) var alertSerial = 0

    /// Why `providers.json` was rejected, shown in the menu.
    private(set) var configError: ProvidersConfigError?
    private(set) var presenter: NotchPresenter

    /// The canvas always has room for this many rows and models, so data arriving rarely resizes it.
    static let minimumCanvasRows = 6
    static let minimumCanvasSections = 2

    let layout: NotchLayout
    let language: AppLanguage
    /// Static renders skip the ring sweep so the PNG shows the final value.
    let animated: Bool

    init(
        layout: NotchLayout,
        language: AppLanguage = .current,
        catalog: ProviderCatalog = .builtIn,
        now: Date = Date(),
        animated: Bool = true
    ) {
        self.layout = layout
        self.language = language
        self.presenter = NotchPresenter(copy: Copy(language: language, catalog: catalog))
        self.now = now
        self.animated = animated
    }

    var mode: NotchMode { machine.mode }
    var catalog: ProviderCatalog { presenter.catalog }

    var restSides: [RestSide] {
        presenter.restSides(snapshots, now: now)
    }

    /// The transparent window: fits the open panel with every model and row it lists now.
    var canvas: CGSize {
        let open = openContent
        return layout.canvasSize(
            rows: max(Self.minimumCanvasRows, open.rowCount),
            sections: max(Self.minimumCanvasSections, open.sections.count)
        )
    }

    var openContent: OpenContent {
        presenter.open(snapshots, issues: issues, now: now)
    }

    var shapeKind: NotchShapeKind {
        switch machine.mode {
        case .rest: .rest
        case .open: .open(rows: openContent.rowCount, sections: openContent.sections.count)
        case .alert: .alert
        }
    }

    var frame: NotchFrame { layout.frame(for: shapeKind) }

    func apply(_ next: NotchMachine) {
        if case let .alert(alert) = next.mode, next.mode != machine.mode {
            alertContent = presenter.alert(alert, now: now)
            alertSerial += 1
        }
        machine = next
    }

    func update(snapshots: [ProviderID: ProviderSnapshot], issues: [ProviderID: ProviderIssue]) {
        self.snapshots = snapshots
        self.issues = issues
    }

    func setCatalog(_ catalog: ProviderCatalog, error: ProvidersConfigError?) {
        presenter = NotchPresenter(copy: Copy(language: language, catalog: catalog))
        configError = error
    }

    func setNow(_ date: Date) {
        now = date
    }
}

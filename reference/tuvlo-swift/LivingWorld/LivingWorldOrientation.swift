import SwiftUI
import UIKit

/// Scoped to the window hosting the World. Other scenes and the parent app keep
/// their normal orientations; leaving restores the orientation used at entry.
@MainActor
final class LivingWorldOrientation {
    static let shared = LivingWorldOrientation()
    static let requestRefused = Notification.Name("TuvloWorldOrientationRequestRefused")
    func restorationOrientation(in scene: UIWindowScene) -> UIInterfaceOrientation {
        leases[ObjectIdentifier(scene)]?.previous ?? scene.interfaceOrientation
    }
    func hasLandscapeLease(in scene: UIWindowScene) -> Bool { leases[ObjectIdentifier(scene)] != nil }
    private final class Lease {
        weak var scene: UIWindowScene?
        var owners: Set<UUID> = []
        let previous: UIInterfaceOrientation
        init(scene: UIWindowScene) { self.scene = scene; previous = scene.interfaceOrientation }
    }
    private var leases: [ObjectIdentifier: Lease] = [:]
    private var flexibleLeases: [ObjectIdentifier: Lease] = [:]

    func mask(for window: UIWindow?) -> UIInterfaceOrientationMask {
        leases = leases.filter { $0.value.scene != nil }
        flexibleLeases = flexibleLeases.filter { $0.value.scene != nil }
        guard let scene = window?.windowScene else { return UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait }
        if leases[ObjectIdentifier(scene)] != nil { return .landscape }
        if flexibleLeases[ObjectIdentifier(scene)] != nil { return scene.traitCollection.userInterfaceIdiom == .pad ? .all : .allButUpsideDown }
        return window?.traitCollection.userInterfaceIdiom == .pad ? .all : .portrait
    }
    func enter(_ scene: UIWindowScene, owner: UUID) {
        let key = ObjectIdentifier(scene)
        leases = leases.filter { $0.value.scene != nil }
        let lease = leases[key] ?? Lease(scene: scene)
        lease.owners.insert(owner); leases[key] = lease
        request(.landscape, in: scene)
    }
    func leave(_ scene: UIWindowScene, owner: UUID) {
        let key = ObjectIdentifier(scene)
        guard let lease = leases[key], lease.owners.remove(owner) != nil else { return }
        if !lease.owners.isEmpty { leases[key] = lease; request(.landscape, in: scene); return }
        leases.removeValue(forKey: key)
        if flexibleLeases[key] != nil {
            request(scene.traitCollection.userInterfaceIdiom == .pad ? .all : .allButUpsideDown, in: scene)
            return
        }
        let mask: UIInterfaceOrientationMask
        switch lease.previous {
        case .landscapeLeft: mask = scene.traitCollection.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        case .landscapeRight: mask = scene.traitCollection.userInterfaceIdiom == .pad ? .landscapeRight : .portrait
        case .portraitUpsideDown: mask = scene.traitCollection.userInterfaceIdiom == .pad ? .portraitUpsideDown : .portrait
        default: mask = .portrait
        }
        request(mask, in: scene)
    }
    func enterFlexible(_ scene: UIWindowScene, owner: UUID) {
        let key = ObjectIdentifier(scene)
        flexibleLeases = flexibleLeases.filter { $0.value.scene != nil }
        let lease = flexibleLeases[key] ?? Lease(scene: scene)
        lease.owners.insert(owner); flexibleLeases[key] = lease
        request(leases[key] == nil ? (scene.traitCollection.userInterfaceIdiom == .pad ? .all : .allButUpsideDown) : .landscape, in: scene)
    }
    func leaveFlexible(_ scene: UIWindowScene, owner: UUID) {
        let key = ObjectIdentifier(scene)
        guard let lease = flexibleLeases[key], lease.owners.remove(owner) != nil else { return }
        if !lease.owners.isEmpty { return }
        flexibleLeases.removeValue(forKey: key)
        if leases[key] != nil { request(.landscape, in: scene); return }
        let prior: UIInterfaceOrientationMask
        if scene.traitCollection.userInterfaceIdiom == .pad {
            switch lease.previous {
            case .landscapeLeft: prior = .landscapeLeft
            case .landscapeRight: prior = .landscapeRight
            case .portraitUpsideDown: prior = .portraitUpsideDown
            default: prior = .portrait
            }
        } else { prior = .portrait }
        request(prior, in: scene)
    }
    private func request(_ mask: UIInterfaceOrientationMask, in scene: UIWindowScene) {
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            window.rootViewController?.presentedViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        // iPad windowed mode may decline rotation. The World then offers a
        // clear expand/turn state, rather than rendering a portrait game.
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in
            // UIKit can deliver a geometry refusal on a background queue.
            // Observers reconcile window/controller state on the main actor.
            Task { @MainActor in
                NotificationCenter.default.post(name: Self.requestRefused, object: scene)
            }
        }
    }
}

struct LivingWorldOrientationAnchor: UIViewControllerRepresentable {
    let active: Bool
    var allowsPortrait = false
    var onRestored: () -> Void = {}
    func makeUIViewController(context: Context) -> Anchor { Anchor(allowsPortrait: allowsPortrait) }
    func updateUIViewController(_ controller: Anchor, context: Context) {
        controller.onRestored = onRestored
        controller.setActive(active)
    }
    static func dismantleUIViewController(_ controller: Anchor, coordinator: ()) { controller.setActive(false) }

    final class Anchor: UIViewController {
        var onRestored: () -> Void = {}
        private var restoration: UIInterfaceOrientation?
        private var transitioning = false
        private let owner = UUID()
        private let allowsPortrait: Bool
        init(allowsPortrait: Bool) {
            self.allowsPortrait = allowsPortrait
            super.init(nibName: nil, bundle: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(requestRefused(_:)), name: LivingWorldOrientation.requestRefused, object: nil)
        }
        required init?(coder: NSCoder) { allowsPortrait = false; super.init(coder: coder) }
        private weak var lockedScene: UIWindowScene?
        private var active = false
        override func loadView() { view = UIView(); view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); reconcile() }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); reconcile() }
        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            transitioning = true
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.transitioning = false
                self?.reconcile()
            }
        }
        @objc private func requestRefused(_ note: Notification) {
            guard !active, restoration != nil, let scene = note.object as? UIWindowScene,
                  scene === viewIfLoaded?.window?.windowScene,
                  !LivingWorldOrientation.shared.hasLandscapeLease(in: scene) else { return }
            finishRestoration()
        }
        private func finishRestoration() {
            restoration = nil
            DispatchQueue.main.async { [weak self] in self?.onRestored() }
        }
        func setActive(_ value: Bool) {
            active = value
            reconcile()
            // Other anchors release their leases in the same SwiftUI update.
            if !value { DispatchQueue.main.async { [weak self] in self?.reconcile() } }
        }
        private func reconcile() {
            let scene = viewIfLoaded?.window?.windowScene
            if let old = lockedScene, !active || old !== scene {
                if allowsPortrait { LivingWorldOrientation.shared.leaveFlexible(old, owner: owner) }
                else { LivingWorldOrientation.shared.leave(old, owner: owner) }
                lockedScene = nil
            }
            if active, let scene, lockedScene !== scene {
                restoration = LivingWorldOrientation.shared.restorationOrientation(in: scene)
                lockedScene = scene
                if allowsPortrait { LivingWorldOrientation.shared.enterFlexible(scene, owner: owner) }
                else { LivingWorldOrientation.shared.enter(scene, owner: owner) }
            }
            if !active, !transitioning, let scene, let restoration,
               !LivingWorldOrientation.shared.hasLandscapeLease(in: scene) {
                let target = scene.traitCollection.userInterfaceIdiom == .pad ? restoration : .portrait
                if scene.interfaceOrientation == target || target == .unknown { finishRestoration() }
            }
        }
    }
}

#if TUVLO_GODOT_NATIVE && !targetEnvironment(simulator)
import SwiftUI
import Combine
import CryptoKit
import UIKit
import SwiftGodot
import SwiftGodotKit

/// One engine per application, with an exclusive child/session lease. A second
/// window gets the existing safe fallback instead of another child's scene.
@MainActor
private final class HomesteadNativeEngine {
    static let shared = HomesteadNativeEngine()
    let app = GodotApp(packFile: "homestead.pck", extraArgs: ["--audio-driver", "Dummy"])
    weak var owner: HomesteadRuntimeBridge?
    var readyHandle: GodotAppViewHandle?
    // The pinned embedding runtime has one Metal window. Reuse its UIView and
    // layer across leases; replacing it leaves stale native surface callbacks.
    lazy var surface = GodotAppView(onReady: { [weak self] handle in
        self?.readyHandle = handle
        self?.owner?.connect(handle)
    })
    // The app bundle cannot change during this process; validate the same pack once.
    private var verifiedPack = false
    func validatePack() -> Bool {
        if verifiedPack { return true }
        struct Manifest: Decodable { let schemaVersion: Int; let packSHA256: String }
        guard let pack = Bundle.main.url(forResource: "homestead", withExtension: "pck"),
              let manifestURL = Bundle.main.url(forResource: "homestead-manifest", withExtension: "json"),
              let bytes = try? Data(contentsOf: pack, options: .mappedIfSafe),
              let manifestBytes = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestBytes), manifest.schemaVersion == 1,
              SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == manifest.packSHA256 else { return false }
        verifiedPack = true
        return true
    }
    func claim(_ bridge: HomesteadRuntimeBridge) -> Bool {
        if let previous = owner, previous !== bridge {
            // A retained but hidden World may yield its scene; an actively
            // displayed child never loses its lease to another window.
            guard !previous.active && !previous.previewing else { return false }
            previous.stop()
        }
        owner = bridge; return true
    }
    func release(_ bridge: HomesteadRuntimeBridge) { if owner === bridge { owner = nil } }
}

@MainActor
final class HomesteadRuntimeBridge: ObservableObject {
    enum Status: Equatable { case loading, ready, failed }
    @Published private(set) var status: Status = .loading
    @Published fileprivate var ownsSurface = false
    private(set) var session = UUID().uuidString
    var onMessage: ((String, [String: Any]) -> Void)?
    private let runtime = HomesteadNativeEngine.shared
    fileprivate var app: GodotApp { runtime.app }
    fileprivate var surface: GodotAppView { runtime.surface }
    private var root: Node?
    private var callback: Callable?
    private var handle: GodotAppViewHandle?
    private var snapshot: HomesteadProjection?
    fileprivate var active = false
    fileprivate var previewing = false
    private var priorIdleTimerState: Bool?
    private var started = false
    private var deadline: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?

    func start() {
        guard !started else { return }
        guard runtime.validatePack(), runtime.claim(self) else { status = .failed; return }
        started = true; session = UUID().uuidString; status = .loading; ownsSurface = true
        app.resume()
        deadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(40))
            guard !Task.isCancelled, let self, self.started, self.status != .ready else { return }
            self.status = .failed
        }
        if let handle = runtime.readyHandle { connect(handle) }
    }
    fileprivate func connect(_ handle: GodotAppViewHandle) {
        self.handle = handle
        guard started, runtime.owner === self, root == nil, connectionTask == nil else { return }
        connectionTask = Task { [weak self] in
            for _ in 0..<200 {
                guard !Task.isCancelled, let self, self.started, self.runtime.owner === self else { return }
                if let node = handle.getRoot()?.findChild(pattern: "TuvloHomestead", recursive: true, owned: false) {
                    let callback = Callable { [weak self] (raw: String) in
                        Task { @MainActor [weak self] in self?.receive(raw) }
                    }
                    guard node.connect(signal: "host_message", callable: callback) == .ok else { self.status = .failed; return }
                    self.root = node; self.callback = callback
                    self.app.resume()
                    self.sendSnapshot()
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            self?.status = .failed
        }
    }
    func update(_ snapshot: HomesteadProjection, active: Bool, previewing: Bool = false) {
        let changed = self.snapshot != snapshot
        let lifecycleChanged = self.active != active || self.previewing != previewing
        self.snapshot = snapshot; self.active = active; self.previewing = previewing
        if (active || previewing) && !started { start() }
        guard started, root != nil, runtime.owner === self else { return }
        keepPerformanceProbeAwake(active)
        if lifecycleChanged && (active || previewing) { app.resume() }
        if changed { sendSnapshot() }
        else if lifecycleChanged {
            send("lifecycle", payload: ["paused": !active, "previewing": previewing])
            if !active && !previewing && status != .loading { app.pause() }
        }
    }
    func send(_ type: String, payload: [String: Any] = [:]) {
        guard started, runtime.owner === self, let root,
              let data = try? JSONSerialization.data(withJSONObject: ["version":1,"session":session,"type":type,"payload":payload]),
              data.count <= 1_000_000, let raw = String(data: data, encoding: .utf8) else { return }
        app.runOnGodotThread { _ = root.call(method: "receive_host_json", Variant(raw)) }
    }
    private func sendSnapshot() {
        guard let snapshot, let bytes = try? JSONEncoder().encode(snapshot),
              let payload = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return }
        keepPerformanceProbeAwake(active)
        send("snapshot", payload: payload)
        send("lifecycle", payload: ["paused": !active, "previewing": previewing])
        if !active && !previewing && status != .loading { app.pause() }
    }
    private func receive(_ raw: String) {
        guard started, runtime.owner === self, raw.utf8.count <= 8192, let data = raw.data(using: .utf8),
              let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              packet["version"] as? Int == 1, packet["session"] as? String == session,
              let type = packet["type"] as? String, let payload = packet["payload"] as? [String: Any] else { return }
        if type == "scenePresented" {
            deadline?.cancel()
            if status != .ready { status = .ready }
            if !active && !previewing { app.pause() }
        }
        if type == "error" { status = .failed }
        onMessage?(type, payload)
    }
    // Explicit developer-only physical profiling mode. Restore the app's prior
    // idle-timer value on background/exit; never alter device Auto-Lock settings.
    private func keepPerformanceProbeAwake(_ awake: Bool) {
        guard ProcessInfo.processInfo.arguments.contains("-homestead-performance-probe") else { return }
        if awake {
            if priorIdleTimerState == nil { priorIdleTimerState = UIApplication.shared.isIdleTimerDisabled }
            UIApplication.shared.isIdleTimerDisabled = true
        } else if let prior = priorIdleTimerState {
            UIApplication.shared.isIdleTimerDisabled = prior
            priorIdleTimerState = nil
        }
    }
    func stop() {
        guard started else { return }
        keepPerformanceProbeAwake(false)
        started = false; deadline?.cancel(); connectionTask?.cancel(); connectionTask = nil
        onMessage = nil
        if runtime.owner === self {
            if let root {
                if let callback { root.disconnect(signal: "host_message", callable: callback) }
                app.runOnGodotThread { _ = root.call(method: "clear_host_session") }
            }
            app.pause(); runtime.release(self)
        }
        root = nil; callback = nil; handle = nil; snapshot = nil; ownsSurface = false
    }
}

struct HomesteadCanvas: View {
    @ObservedObject var bridge: HomesteadRuntimeBridge
    var body: some View {
        Group {
            if bridge.ownsSurface {
                bridge.surface
                    .environment(\.godotApp, bridge.app)
                    .accessibilityHidden(true)
            } else { Color.clear }
        }.onDisappear { bridge.stop() }
    }
}
#endif

#if !TUVLO_GODOT_NATIVE || targetEnvironment(simulator)
import SwiftUI
import Combine
import WebKit
import CryptoKit

@MainActor
final class HomesteadRuntimeBridge: NSObject, ObservableObject, WKNavigationDelegate {
    enum Status: Equatable { case loading, ready, failed }
    @Published private(set) var status: Status = .loading
    private(set) var session = UUID().uuidString
    let web: WKWebView
    var onMessage: ((String, [String: Any]) -> Void)?
    private var proxy: MessageProxy?
    private var server: HomesteadAssetServer?
    private var launchURL: URL?
    private var snapshot: HomesteadProjection?
    private var active = false
    private var previewing = false
    private var engineReady = false
    private var deadline: Task<Void, Never>?
    private var stopped = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        web = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        let proxy = MessageProxy(owner: self); self.proxy = proxy
        configuration.userContentController.add(proxy, name: "world")
        web.navigationDelegate = self
        web.isOpaque = false
        web.backgroundColor = UIColor(CartoonTheme.kidBgTop)
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isAccessibilityElement = false
        // Accessible semantic controls and descriptions live in native SwiftUI.
        web.accessibilityElementsHidden = true
    }
    func start() {
        guard server == nil else { return }
        if stopped {
            stopped = false; engineReady = false; launchURL = nil; session = UUID().uuidString
            let proxy = MessageProxy(owner: self); self.proxy = proxy
            web.configuration.userContentController.add(proxy, name: "world")
            web.navigationDelegate = self
        }
        status = .loading
        guard let root = Bundle.main.url(forResource: "WorldWeb", withExtension: nil) else { status = .failed; return }
        do {
            struct Manifest: Decodable { let files: [String: String] }
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
            // Bundle integrity also detects Git LFS pointer files in developer builds.
            for (name, digest) in manifest.files {
                guard name == (name as NSString).lastPathComponent, !name.contains("..") else { status = .failed; return }
                let bytes = try Data(contentsOf: root.appendingPathComponent(name), options: .mappedIfSafe)
                guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == digest else { status = .failed; return }
            }
            let server = HomesteadAssetServer(root: root, files: Set(manifest.files.keys))
            self.server = server
            try server.start(ready: { [weak self] url in
                Task { @MainActor [weak self] in
                    guard let self, !self.stopped else { return }
                    self.launchURL = url; self.web.load(URLRequest(url: url))
                }
            }, failed: { [weak self] in Task { @MainActor [weak self] in self?.status = .failed } })
            deadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(40))
                guard !Task.isCancelled, let self, self.status != .ready else { return }
                self.status = .failed
            }
        } catch { status = .failed }
    }
    func update(_ snapshot: HomesteadProjection, active: Bool, previewing: Bool = false) {
        let changed = self.snapshot != snapshot
        let lifecycleChanged = self.active != active || self.previewing != previewing
        self.snapshot = snapshot
        self.active = active
        self.previewing = previewing
        if engineReady && changed { sendSnapshot() }
        else if engineReady && lifecycleChanged { send("lifecycle", payload: ["paused": !active, "previewing": previewing]) }
    }
    func send(_ type: String, payload: [String: Any] = [:]) {
        guard engineReady, !stopped,
              let bytes = try? JSONSerialization.data(withJSONObject: ["version": 1, "session": session, "type": type, "payload": payload]),
              let json = String(data: bytes, encoding: .utf8) else { return }
        Task { [weak self] in
            guard let self, !self.stopped else { return }
            do { _ = try await self.web.callAsyncJavaScript("window.tuvloReceive(packet);", arguments: ["packet": json], in: nil, contentWorld: .page) }
            catch { if !self.stopped { self.status = .failed } }
        }
    }
    private func sendSnapshot() {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        send("snapshot", payload: payload)
        send("lifecycle", payload: ["paused": !active, "previewing": previewing])
    }
    private func receive(_ message: WKScriptMessage) {
        guard !stopped, message.frameInfo.isMainFrame, let origin = launchURL,
              message.frameInfo.request.url == origin,
              message.frameInfo.securityOrigin.host == origin.host,
              message.frameInfo.securityOrigin.port == origin.port,
              let raw = message.body as? String, raw.utf8.count <= 8192,
              let data = raw.data(using: .utf8),
              let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              packet["version"] as? Int == 1, let type = packet["type"] as? String,
              let payload = packet["payload"] as? [String: Any] else { return }
        if type == "ready", packet["session"] as? String == "", !engineReady {
            engineReady = true; sendSnapshot(); return
        }
        if type == "error", !engineReady { status = .failed; return }
        guard packet["session"] as? String == session else { return }
        if type == "scenePresented" { deadline?.cancel(); if status != .ready { status = .ready } }
        if type == "error" { status = .failed }
        onMessage?(type, payload)
    }
    func stop() {
        guard !stopped else { return }
        stopped = true; deadline?.cancel(); deadline = nil
        onMessage = nil; web.stopLoading(); web.navigationDelegate = nil
        web.configuration.userContentController.removeScriptMessageHandler(forName: "world")
        proxy?.owner = nil; proxy = nil; server?.stop(); server = nil
        web.loadHTMLString("", baseURL: nil)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.targetFrame?.isMainFrame == true, let url = action.request.url,
              url == launchURL else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { engineReady = false; status = .failed }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if !stopped { status = .failed } }
    private final class MessageProxy: NSObject, WKScriptMessageHandler {
        weak var owner: HomesteadRuntimeBridge?
        init(owner: HomesteadRuntimeBridge) { self.owner = owner }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { owner?.receive(message) }
    }
}

struct HomesteadCanvas: UIViewRepresentable {
    let bridge: HomesteadRuntimeBridge
    func makeCoordinator() -> HomesteadRuntimeBridge { bridge }
    func makeUIView(context: Context) -> WKWebView { bridge.web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: HomesteadRuntimeBridge) { coordinator.stop() }
}

#endif

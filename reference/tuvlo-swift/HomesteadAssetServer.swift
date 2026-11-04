import Foundation
import Network

/// A read-only loopback transport for bundled WebAssembly; it exposes neither
/// application documents nor remote URLs. All mutable connection state uses queue.
nonisolated final class HomesteadAssetServer: @unchecked Sendable {
    private let root: URL
    private let allowed: Set<String>
    private let token = UUID().uuidString
    private let queue = DispatchQueue(label: "tuvlo.homestead.assets", qos: .userInitiated)
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    init(root: URL, files: Set<String>) { self.root = root; allowed = files }
    func start(ready: @escaping @Sendable (URL) -> Void, failed: @escaping @Sendable () -> Void) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener else { return }
            if case .ready = state, let port = listener.port,
               let url = URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token)/index.html") { ready(url) }
            if case .failed = state { failed() }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self, self.connections.count < 8 else { connection.cancel(); return }
            let id = UUID(); self.connections[id] = connection
            connection.start(queue: self.queue)
            self.queue.asyncAfter(deadline: .now() + 30) { [weak self] in self?.finish(id) }
            self.receive(id, accumulated: Data())
        }
        listener.start(queue: queue)
    }
    func stop() {
        queue.async { [self] in
            listener?.stateUpdateHandler = nil; listener?.newConnectionHandler = nil
            listener?.cancel(); listener = nil
            for connection in connections.values { connection.cancel() }
            connections.removeAll()
        }
    }
    private func finish(_ id: UUID) { connections.removeValue(forKey: id)?.cancel() }
    private func receive(_ id: UUID, accumulated: Data) {
        guard let connection = connections[id] else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] bytes, _, done, error in
            guard let self else { connection.cancel(); return }
            let request = accumulated + (bytes ?? Data())
            guard error == nil, request.count <= 8192 else { self.finish(id); return }
            if let text = String(data: request, encoding: .utf8), text.contains("\r\n\r\n") { self.respond(id, request: text) }
            else if done { self.finish(id) }
            else { self.receive(id, accumulated: request) }
        }
    }
    private func respond(_ id: UUID, request: String) {
        guard let connection = connections[id] else { return }
        let fields = request.components(separatedBy: "\r\n")[0].split(separator: " ")
        let prefix = "/\(token)/"
        guard fields.count == 3, fields[0] == "GET", fields[1].hasPrefix(prefix) else { finish(id); return }
        let name = String(fields[1].dropFirst(prefix.count))
        guard allowed.contains(name), !name.contains("/"), !name.contains("%"), !name.contains(".."),
              let data = try? Data(contentsOf: root.appendingPathComponent(name), options: .mappedIfSafe) else { finish(id); return }
        let ext = (name as NSString).pathExtension
        let mime = ["html":"text/html; charset=utf-8", "js":"application/javascript", "wasm":"application/wasm", "css":"text/css", "png":"image/png"][ext] ?? "application/octet-stream"
        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(mime)\r\nContent-Length: \(data.count)\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil else { self?.finish(id); return }
            self?.send(id, data: data, offset: 0)
        })
    }
    private func send(_ id: UUID, data: Data, offset: Int) {
        guard let connection = connections[id] else { return }
        if offset == data.count { finish(id); return }
        let end = min(data.count, offset + 65536)
        connection.send(content: data.subdata(in: offset..<end), completion: .contentProcessed { [weak self] error in
            guard error == nil else { self?.finish(id); return }
            self?.send(id, data: data, offset: end)
        })
    }
    deinit { listener?.cancel(); for connection in connections.values { connection.cancel() } }
}

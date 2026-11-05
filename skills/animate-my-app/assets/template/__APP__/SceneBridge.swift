import SwiftUI
import WebKit

/// Serves bundled files over `appbundle://` so every file (scripts, textures) is same-origin —
/// WebGL refuses textures loaded from `file://` URLs.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "appbundle"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let file = Bundle.main.url(forResource: url.lastPathComponent, withExtension: nil),
              let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime: String
        switch file.pathExtension.lowercased() {
        case "html": mime = "text/html; charset=utf-8"
        case "js": mime = "text/javascript; charset=utf-8"
        case "json": mime = "application/json"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "webp": mime = "image/webp"
        case "glb": mime = "model/gltf-binary"
        default: mime = "application/octet-stream"
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)",
                                                      "Cache-Control": "no-store"])!   // never a stale script after a reinstall
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

/// Owns the WKWebView that renders the three.js scene and bridges its timeline cues to SwiftUI.
/// Created eagerly at app launch so the web process spins up in parallel with the app.
final class SceneBridge: NSObject, WKScriptMessageHandler {
    static let shared = SceneBridge()

    let webView: WKWebView
    var onEvent: ((String) -> Void)?

    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()                  // no disk cache between launches
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: BundleSchemeHandler.scheme)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 402, height: 874), configuration: config)
        super.init()
        config.userContentController.add(self, name: "scene")

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        // look-dev / test flags: SIMCTL_CHILD_SCENE_QUERY="perf&debug" xcrun simctl launch booted <bundle id>
        let query = ProcessInfo.processInfo.environment["SCENE_QUERY"].map { "?\($0)" } ?? ""
        if let url = URL(string: "\(BundleSchemeHandler.scheme)://app/scene.html\(query)") {
            webView.load(URLRequest(url: url))
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let event = message.body as? String else { return }
        if event.hasPrefix("perf:") { NSLog("[scene] %@", event); return }   // frame-time probe (?perf)
        onEvent?(event)
    }

    func replay() {
        webView.evaluateJavaScript("window.scenePlay && window.scenePlay()")
    }
}

/// Transparent, non-interactive layer that shows the three.js scene above the native background.
struct SceneLayer: UIViewRepresentable {
    let bridge: SceneBridge

    func makeUIView(context: Context) -> WKWebView { bridge.webView }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}

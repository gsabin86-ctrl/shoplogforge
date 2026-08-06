import UIKit
import WebKit

final class ShopLogViewController: UIViewController {
    private static let bridgeName = "shoplog"
    private var webView: WKWebView!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 3 / 255, green: 7 / 255, blue: 18 / 255, alpha: 1)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(self, name: Self.bridgeName)

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = view.backgroundColor
        webView.isOpaque = false
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        view.addSubview(webView)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            webView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            webView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])

        guard
            let appURL = Bundle.main.url(forResource: "shoplog", withExtension: "html"),
            let appHTML = try? String(contentsOf: appURL, encoding: .utf8),
            let stableOrigin = URL(string: "https://shoplog.local/")
        else {
            showNativeError("The bundled ShopLog interface is missing.")
            return
        }
        webView.loadHTMLString(appHTML, baseURL: stableOrigin)
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.bridgeName)
    }

    private func saveExport(message: [String: Any]) {
        guard
            let rawFilename = message["filename"] as? String,
            let encoded = message["base64"] as? String,
            let data = Data(base64Encoded: encoded)
        else {
            showWebToast("Could not prepare that export", isError: true)
            return
        }

        let filename = sanitizeFilename(rawFilename)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let documents = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
                let exportFolder = documents.appendingPathComponent("Exports", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: exportFolder,
                    withIntermediateDirectories: true
                )
                let destination = exportFolder.appendingPathComponent(filename, isDirectory: false)
                try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])

                DispatchQueue.main.async {
                    self?.showWebToast("Saved to Files → On My iPhone → ShopLog → Exports")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showWebToast("Could not save \(filename)", isError: true)
                }
            }
        }
    }

    private func sanitizeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|\r\n")
        let cleaned = value
            .components(separatedBy: invalid)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "shoplog-export.bin" : cleaned
    }

    private func showWebToast(_ text: String, isError: Bool = false) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: [text, isError]),
              let json = String(data: jsonData, encoding: .utf8) else {
            return
        }
        webView.evaluateJavaScript("showToast.apply(null, \(json));")
    }

    private func showNativeError(_ text: String) {
        let alert = UIAlertController(title: "ShopLog", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func openExternally(_ url: URL) {
        UIApplication.shared.open(url, options: [:])
    }
}

extension ShopLogViewController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            message.name == Self.bridgeName,
            let body = message.body as? [String: Any],
            body["action"] as? String == "saveFile"
        else {
            return
        }
        saveExport(message: body)
    }
}

extension ShopLogViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let externalSchemes = ["http", "https", "mailto", "tel"]
        if let scheme = url.scheme?.lowercased(), externalSchemes.contains(scheme) {
            openExternally(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

extension ShopLogViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            openExternally(url)
        }
        return nil
    }
}

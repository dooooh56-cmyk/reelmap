import UIKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class ShareViewController: UIViewController {
    private let library = Library()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task { await loadSharedPost() }
    }
    private func loadSharedPost() async {
        var sharedURL = "", sharedText = ""
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                let item = await load(provider, type: UTType.url.identifier)
                if let url = item as? URL { sharedURL = url.absoluteString }
                else if let string = item as? String { sharedURL = string }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let string = await load(provider, type: UTType.plainText.identifier) as? String { sharedText += string + "\n" }
            }
        }
        if sharedURL.isEmpty, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let ns = sharedText as NSString
            sharedURL = detector.matches(in: sharedText, range: NSRange(location: 0, length: ns.length)).compactMap(\.url).first(where: { ["www.instagram.com", "instagram.com"].contains($0.host ?? "") })?.absoluteString ?? ""
        }
        let supplementalText = sharedText.replacingOccurrences(of: sharedURL, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let content = NavigationStack {
            AnalyzeView(library: library, initialURL: sharedURL, initialText: supplementalText, onDone: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }, autoStart: !sharedURL.isEmpty)
        }.tint(.green)
        let host = UIHostingController(rootView: content)
        addChild(host); view.addSubview(host.view); host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        host.didMove(toParent: self)
    }
    private func load(_ provider: NSItemProvider, type: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in continuation.resume(returning: item) } }
    }
}

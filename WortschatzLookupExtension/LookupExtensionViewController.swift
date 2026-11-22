import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(LookupExtensionViewController)
public final class LookupExtensionViewController: UIViewController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        extractSharedText { [weak self] sharedText in
            DispatchQueue.main.async {
                self?.presentLookupInterface(with: sharedText)
            }
        }
    }
    
    private func presentLookupInterface(with rawText: String) {
        let lookupView = QuickLookupView(
            rawText: rawText,
            store: nil,
            isExtensionMode: true,
            onClose: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            },
            onOpenInMainApp: { [weak self] query in
                self?.openMainApp(withQuery: query)
            }
        )
        
        let hostingController = UIHostingController(rootView: lookupView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    private func extractSharedText(completion: @escaping (String) -> Void) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion("")
            return
        }
        
        var collectedPieces: [String] = []
        let group = DispatchGroup()
        let lock = NSLock()
        
        for item in extensionItems {
            if let attributedContent = item.attributedContentText?.string,
               !attributedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lock.lock()
                collectedPieces.append(attributedContent)
                lock.unlock()
            }
            
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                        defer { group.leave() }
                        if let str = Self.decodeItem(data) {
                            lock.lock()
                            collectedPieces.append(str)
                            lock.unlock()
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                        defer { group.leave() }
                        if let str = Self.decodeItem(data) {
                            lock.lock()
                            collectedPieces.append(str)
                            lock.unlock()
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        defer { group.leave() }
                        if let url = data as? URL, !url.isFileURL {
                            // Only use URL string if no plain text was provided
                            lock.lock()
                            if collectedPieces.isEmpty {
                                collectedPieces.append(url.lastPathComponent.replacingOccurrences(of: "-", with: " "))
                            }
                            lock.unlock()
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            let bestPiece = collectedPieces
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.lowercased().hasPrefix("http") }
                .first ?? collectedPieces.first ?? ""
            completion(bestPiece)
        }
    }
    
    private static func decodeItem(_ item: NSSecureCoding?) -> String? {
        if let str = item as? String {
            return str
        }
        if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
            return str
        }
        if let url = item as? URL {
            return url.absoluteString
        }
        return nil
    }
    
    private func openMainApp(withQuery query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "wortschatz://lookup?q=\(encoded)") else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        var responder: UIResponder? = self
        let selectorOpenURL = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selectorOpenURL) {
                _ = current.perform(selectorOpenURL, with: url)
                break
            }
            responder = current.next
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}

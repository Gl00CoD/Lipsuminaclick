import AppKit
import LipsumCore

enum TextMode: String {
    case sentence
    case paragraph
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let sentenceItem = NSMenuItem(title: "Sentence", action: #selector(selectSentence), keyEquivalent: "")
    private let paragraphItem = NSMenuItem(title: "Paragraph", action: #selector(selectParagraph), keyEquivalent: "")
    private var resetIconWork: DispatchWorkItem?

    private static let modeKey = "textMode"

    private var mode: TextMode {
        get {
            let stored = UserDefaults.standard.string(forKey: Self.modeKey) ?? ""
            return TextMode(rawValue: stored) ?? .sentence
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.modeKey)
            updateCheckmarks()
        }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Self.symbol("text.alignleft", description: "Lipsum in a Click")
            button.toolTip = "Click to copy lorem ipsum · Right-click for options"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        buildMenu()
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        sentenceItem.target = self
        paragraphItem.target = self
        menu.addItem(sentenceItem)
        menu.addItem(paragraphItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Lipsum in a Click", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        updateCheckmarks()
    }

    private func updateCheckmarks() {
        sentenceItem.state = mode == .sentence ? .on : .off
        paragraphItem.state = mode == .paragraph ? .on : .off
    }

    private func showMenu() {
        // Attach the menu only while it's open, so a plain left click keeps copying.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // MARK: Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            copyText()
            return
        }
        let isRightClick = event.type == .rightMouseUp
        let isControlClick = event.modifierFlags.contains(.control)
        if isRightClick || isControlClick {
            showMenu()
        } else {
            copyText()
        }
    }

    @objc private func selectSentence() { mode = .sentence }
    @objc private func selectParagraph() { mode = .paragraph }
    @objc private func quit() { NSApp.terminate(nil) }

    private func copyText() {
        let text: String
        switch mode {
        case .sentence: text = LoremGenerator.sentence()
        case .paragraph: text = LoremGenerator.paragraph()
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        flashConfirmation()
    }

    /// Briefly swaps the icon for a checkmark so you know the copy worked.
    private func flashConfirmation() {
        guard let button = statusItem.button else { return }
        resetIconWork?.cancel()
        button.image = Self.symbol("checkmark", description: "Copied")
        let work = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.image = Self.symbol("text.alignleft", description: "Lipsum in a Click")
        }
        resetIconWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private static func symbol(_ name: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }
}

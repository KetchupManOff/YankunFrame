import Cocoa
import WebKit

// ── App Delegate ─────────────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var serverTask: Process?
    var cursorHideTimer: Timer?
    let cursorIdleTimeout: TimeInterval = 3.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create a borderless full-screen window FIRST (unblock main thread!)
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 4096, height: 2304)

        window = NSWindow(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "YankunFrame"
        window.isOpaque = true
        window.backgroundColor = NSColor.black
        window.delegate = self

        // ── True kiosk: fullscreen space + hidden chrome ──
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAuxiliary]
        NSApp.presentationOptions = [.hideMenuBar, .hideDock]

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 2. Create WebKit view
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // Persist localStorage between launches

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")  // Transparent bg
        window.contentView?.addSubview(webView)

        // 3. Launch the Python server (non-blocking)
        launchServer()

        // 4. Defer page load by 2s to give the server time to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let url = URL(string: "http://127.0.0.1:8080") {
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                self.webView.load(request)
            }
        }

        // 5. Enter native fullscreen space (separate Space, no menu bar/Dock)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.window.toggleFullScreen(nil)
        }

        // 7. Keyboard event monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // If a native popup/select is open, never intercept anything
            // (firstResponder won't be our WebView or its contentView)
            if let responder = self.window.firstResponder {
                if responder !== self.webView && responder !== self.window.contentView {
                    return event  // pass through for native popups, selects, menus
                }
            }

            switch event.keyCode {
            case 3:    // F key → toggle fullscreen on/off
                self.window.toggleFullScreen(nil)
                return nil
            case 53:   // Escape → do nothing (prevent exiting fullscreen)
                return nil
            default:
                break
            }

            return event
        }

        // 8. Mouse / keyboard activity → reset cursor auto-hide timer
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown]) { [weak self] event in
            self?.resetCursorTimer()
            return event
        }

        // 9. Start cursor auto-hide
        resetCursorTimer()
    }

    // ── Cursor auto-hide ──────────────────────────────────
    func resetCursorTimer() {
        NSCursor.unhide()
        cursorHideTimer?.invalidate()
        cursorHideTimer = Timer.scheduledTimer(withTimeInterval: cursorIdleTimeout, repeats: false) { [weak self] _ in
            self?.cursorHideTimerFired()
        }
    }

    func cursorHideTimerFired() {
        NSCursor.hide()
    }

    // ── NSWindowDelegate: lock chrome in fullscreen ───────
    func windowDidEnterFullScreen(_ notification: Notification) {
        NSApp.presentationOptions = [.hideMenuBar, .hideDock]
        resetCursorTimer()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        NSApp.presentationOptions = [.hideMenuBar, .hideDock]
        resetCursorTimer()
    }

    func evaluateJS(_ script: String) {
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    func launchServer() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["server.py"]

        // Set working directory to the app's Resources folder
        if let resourcePath = Bundle.main.resourcePath {
            process.currentDirectoryURL = URL(fileURLWithPath: resourcePath)
        }

        do {
            try process.run()
            print("[YankunFrame] Python server started (PID: \(process.processIdentifier))")
        } catch {
            print("[YankunFrame] Failed to start server: \(error)")
        }
    }

    // Keep app running
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// ── Entry point ──────────────────────────────────────────
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
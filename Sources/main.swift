// ClaudeSwitcher: 前面の Terminal タブで動いている Claude Code のアカウントを
// メニューバーから切り替える。実際の処理は ~/.local/bin/ccx に委譲する。
import AppKit
import ServiceManagement

let ccxPath = NSHomeDirectory() + "/.local/bin/ccx"

struct CommandResult { let status: Int32; let output: String }

func runCcx(_ args: [String]) -> CommandResult {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = [ccxPath] + args
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = NSHomeDirectory() + "/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return CommandResult(status: -1, output: error.localizedDescription) }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return CommandResult(status: p.terminationStatus, output: out)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var current = ""
    /// 最後に前面タブで検出したアカウント（未検出なら `claude` = `ccx main` に合わせて main）
    private let lastKnownKey = "lastKnownAccount"
    private lazy var lastKnown = UserDefaults.standard.string(forKey: lastKnownKey) ?? "main"
    private var accounts: [(name: String, email: String)] = []
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "Claude アカウント")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.font = NSFont.menuBarFont(ofSize: 11)
        }
        menu.delegate = self
        statusItem.menu = menu
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// 前面タブのアカウントと登録済みアカウントをバックグラウンドで取得してタイトルに反映する
    private func refresh(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            let cur = runCcx(["current"])
            let list = runCcx(["list", "--tsv"])
            let parsed: [(String, String)] = list.output.split(separator: "\n").compactMap { line in
                let cols = line.split(separator: "\t", maxSplits: 1).map(String.init)
                return cols.count == 2 ? (cols[0], cols[1]) : nil
            }
            DispatchQueue.main.async {
                self.current = cur.status == 0 ? cur.output : ""
                self.accounts = parsed.map { (name: $0.0, email: $0.1) }
                if !self.current.isEmpty && self.current != self.lastKnown {
                    self.lastKnown = self.current
                    UserDefaults.standard.set(self.current, forKey: self.lastKnownKey)
                }
                // 前面タブで Claude が動いていなくても、最後に検出したアカウント名を表示し続ける
                self.statusItem.button?.title = " " + self.displayName(self.current.isEmpty ? self.lastKnown : self.current)
                completion?()
            }
        }
    }

    /// メニューバー表示名（ccx の内部名は小文字。表記を変えたいものだけここで指定）
    /// Mac ごとに main のアカウントが異なる場合は UserDefaults で上書きする:
    ///   defaults write jp.co.withfox.ClaudeSwitcher displayNames -dict main WithFox
    private lazy var displayNames: [String: String] = {
        var names = ["main": "ALBONA", "withfox": "WithFox", "albona": "ALBONA"]
        if let overrides = UserDefaults.standard.dictionary(forKey: "displayNames") as? [String: String] {
            names.merge(overrides) { _, new in new }
        }
        return names
    }()

    private func displayName(_ name: String) -> String {
        return displayNames[name] ?? name.uppercased()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header: String
        if current.isEmpty {
            header = "前面の Terminal タブで Claude が動いていません（最後に使用: \(displayName(lastKnown))）"
        } else {
            let email = accounts.first { $0.name == current }?.email ?? ""
            header = "前面のタブ: \(displayName(current))（\(email)）"
        }
        let headerItem = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        for account in accounts where account.name != current {
            let item = NSMenuItem(title: "\(displayName(account.name)) に切り替え（\(account.email)）",
                                  action: current.isEmpty ? nil : #selector(switchAccount(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = account.name
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let quit = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        refresh()
    }

    @objc private func switchAccount(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runCcx(["tab-switch", name])
            DispatchQueue.main.async {
                if result.status != 0 { self.showError(result.output) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refresh() }
            }
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError("ログイン項目の設定に失敗しました: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "アカウントを切り替えできませんでした"
        alert.informativeText = message.replacingOccurrences(of: "ccx: ", with: "")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

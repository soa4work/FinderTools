import Cocoa
import CryptoKit
import FinderSync

/// Finder Sync-расширение: добавляет пункты в контекстное меню Finder и кнопку на панель инструментов.
///
/// Важно: Finder копирует пункты меню и сохраняет только title, image, action, tag и submenu.
/// Поэтому параметры передаются через `tag`, а контекст вызова запоминается в `menu(for:)`.
final class FinderSync: FIFinderSync {

    private enum Context { case items, container, toolbar }
    private var context: Context = .container
    private var finder: FIFinderSyncController { FIFinderSyncController.default() }

    override init() {
        super.init()
        updateMonitoredDirectories()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(volumesChanged), name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(volumesChanged), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    @objc private func volumesChanged(_ note: Notification) { updateMonitoredDirectories() }

    /// Следим за всем диском и подключёнными томами, чтобы меню было везде.
    private func updateMonitoredDirectories() {
        var urls: Set<URL> = [URL(fileURLWithPath: "/")]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil,
                                                            options: [.skipHiddenVolumes]) ?? []
        urls.formUnion(volumes)
        finder.directoryURLs = urls
    }

    // MARK: - Панель инструментов

    override var toolbarItemName: String { "FinderTools" }
    override var toolbarItemToolTip: String { "Новый файл, копирование пути и другое" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "FinderTools")
            ?? NSImage(named: NSImage.actionTemplateName)!
    }

    // MARK: - Меню

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        switch menuKind {
        case .contextualMenuForItems: context = .items
        case .contextualMenuForContainer: context = .container
        case .toolbarItemMenu: context = .toolbar
        default: return nil
        }

        // Настройки читаются при каждом открытии меню, поэтому изменения применяются сразу.
        let settings = SettingsStorage.load()
        let hasSelection = context != .container && !(finder.selectedItemURLs() ?? []).isEmpty
        func visible(_ action: MenuAction) -> Bool {
            settings.isEnabled(action) && (!action.requiresSelection || hasSelection)
        }
        func actionItem(_ action: MenuAction, tag: Int = 0) -> NSMenuItem {
            item(action.title, action.symbol, selector(for: action), tag: tag)
        }

        var items: [NSMenuItem] = []

        // Новый файл
        let newFile = NSMenu(title: "")
        if visible(.newFile) {
            for (index, template) in FileTemplate.all.enumerated() where settings.isEnabled(template) {
                newFile.addItem(item(template.title, template.symbol, #selector(createFile(_:)), tag: index))
            }
        }
        if visible(.newFromClipboard) {
            if !newFile.items.isEmpty { newFile.addItem(.separator()) }
            newFile.addItem(item("Из буфера обмена", MenuAction.newFromClipboard.symbol,
                                 #selector(createFromClipboard(_:))))
        }
        if !newFile.items.isEmpty { items.append(submenu("Новый файл", "doc.badge.plus", newFile)) }

        // Копирование
        if visible(.copyPath) { items.append(actionItem(.copyPath)) }
        let copy = NSMenu(title: "")
        for action in MenuAction.allCases where action.group == .copy && action != .copyPath && visible(action) {
            if action == .copyContents, !copy.items.isEmpty { copy.addItem(.separator()) }
            copy.addItem(actionItem(action))
        }
        if !copy.items.isEmpty { items.append(submenu("Скопировать…", "doc.on.doc", copy)) }

        // Открыть в
        if visible(.openIn) {
            let open = NSMenu(title: "")
            var lastKind: OpenApp.Kind?
            for (index, app) in OpenApp.all.enumerated() where settings.isEnabled(app) {
                guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else { continue }
                if let lastKind, lastKind != app.kind { open.addItem(.separator()) }
                lastKind = app.kind
                let entry = item(app.title, nil, #selector(openInApp(_:)), tag: index)
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                icon.size = NSSize(width: 16, height: 16)
                entry.image = icon
                open.addItem(entry)
            }
            if !open.items.isEmpty { items.append(submenu("Открыть в", "arrow.up.forward.app", open)) }
        }

        // Ещё
        let more = NSMenu(title: "")
        for action in MenuAction.allCases where action.group == .more && visible(action) {
            more.addItem(actionItem(action))
        }
        if !more.items.isEmpty { items.append(submenu("Ещё", "ellipsis.circle", more)) }

        guard !items.isEmpty else { return nil }

        let menu = NSMenu(title: "")
        if settings.groupInSubmenu && context != .toolbar {
            let root = NSMenu(title: "")
            items.forEach(root.addItem)
            menu.addItem(submenu("FinderTools", "wrench.and.screwdriver", root))
        } else {
            items.forEach(menu.addItem)
        }
        return menu
    }

    private func selector(for action: MenuAction) -> Selector {
        switch action {
        case .newFile: return #selector(createFile(_:))
        case .newFromClipboard: return #selector(createFromClipboard(_:))
        case .copyPath: return #selector(copyPath(_:))
        case .copyName: return #selector(copyName(_:))
        case .copyNameWithoutExtension: return #selector(copyNameWithoutExtension(_:))
        case .copyShellPath: return #selector(copyShellPath(_:))
        case .copyTildePath: return #selector(copyTildePath(_:))
        case .copyParentPath: return #selector(copyParentPath(_:))
        case .copyFileURL: return #selector(copyFileURL(_:))
        case .copyContents: return #selector(copyContents(_:))
        case .copySHA256: return #selector(copySHA256(_:))
        case .openIn: return #selector(openInApp(_:))
        case .makeExecutable: return #selector(makeExecutable(_:))
        case .createSymlink: return #selector(createSymlink(_:))
        }
    }

    private func item(_ title: String, _ symbol: String?, _ action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.tag = tag
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return item
    }

    private func submenu(_ title: String, _ symbol: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.submenu = menu
        return item
    }

    // MARK: - Цели действий

    /// Объекты, к которым применяется действие (выделенные файлы или текущая папка).
    private var targetURLs: [URL] {
        let selected = finder.selectedItemURLs() ?? []
        switch context {
        case .items:
            return selected
        case .container:
            return finder.targetedURL().map { [$0] } ?? []
        case .toolbar:
            return selected.isEmpty ? (finder.targetedURL().map { [$0] } ?? []) : selected
        }
    }

    /// Папка, в которой создаются новые файлы: если выделена одна папка — внутри неё,
    /// если выделены файлы — рядом с первым (в режиме списка это может быть раскрытая подпапка), иначе текущая.
    private var destinationDirectory: URL? {
        if context != .container, let first = finder.selectedItemURLs()?.first {
            if finder.selectedItemURLs()?.count == 1, isFolder(first) { return first }
            return first.deletingLastPathComponent()
        }
        return finder.targetedURL()
    }

    private func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }

    /// Обычный файл (не папка и не бандл вроде .app). Симлинки разыменовываются.
    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }

    private func uniqueURL(in directory: URL, base: String, ext: String) -> URL {
        func candidate(_ n: Int) -> URL {
            let name = n == 1 ? base : "\(base) \(n)"
            return directory.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
        }
        var n = 1
        while FileManager.default.fileExists(atPath: candidate(n).path) { n += 1 }
        return candidate(n)
    }

    private func fail(_ error: Error? = nil) {
        if let error { NSLog("FinderTools: %@", String(describing: error)) }
        NSSound.beep()
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func copyLines(_ transform: (URL) -> String) {
        let urls = targetURLs
        guard !urls.isEmpty else { return fail() }
        copyToPasteboard(urls.map(transform).joined(separator: "\n"))
    }


    // MARK: - Создание файлов

    @objc func createFile(_ sender: NSMenuItem) {
        guard FileTemplate.all.indices.contains(sender.tag), let dir = destinationDirectory else { return fail() }
        let template = FileTemplate.all[sender.tag]
        let url = uniqueURL(in: dir, base: template.baseName, ext: template.ext)
        do {
            try Data(template.content.utf8).write(to: url, options: .withoutOverwriting)
            if template.executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        } catch {
            fail(error)
        }
    }

    /// Сохраняет текст из буфера в .txt, а картинку — в .png.
    @objc func createFromClipboard(_ sender: NSMenuItem) {
        guard let dir = destinationDirectory else { return fail() }
        let pasteboard = NSPasteboard.general
        // Скопированный в Finder файл лежит в буфере ещё и строкой с именем.
        // Вставлять файлы умеет сам Finder (Cmd+V), поэтому здесь отказываемся, а не пишем имя в .txt.
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            return fail()
        }
        do {
            if let text = pasteboard.string(forType: .string) {
                let url = uniqueURL(in: dir, base: "Из буфера обмена", ext: "txt")
                try Data(text.utf8).write(to: url, options: .withoutOverwriting)
            } else if let image = NSImage(pasteboard: pasteboard),
                      let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                let url = uniqueURL(in: dir, base: "Из буфера обмена", ext: "png")
                try png.write(to: url, options: .withoutOverwriting)
            } else {
                fail()
            }
        } catch {
            fail(error)
        }
    }

    // MARK: - Копирование

    @objc func copyPath(_ sender: NSMenuItem) { copyLines { $0.path } }

    @objc func copyName(_ sender: NSMenuItem) { copyLines { $0.lastPathComponent } }

    @objc func copyNameWithoutExtension(_ sender: NSMenuItem) {
        copyLines { $0.deletingPathExtension().lastPathComponent }
    }

    @objc func copyShellPath(_ sender: NSMenuItem) {
        copyLines { "'" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    }

    @objc func copyTildePath(_ sender: NSMenuItem) {
        copyLines { url in
            let path = url.path
            if path == SettingsStorage.realHome { return "~" }
            if path.hasPrefix(SettingsStorage.realHome + "/") { return "~" + path.dropFirst(SettingsStorage.realHome.count) }
            return path
        }
    }

    @objc func copyParentPath(_ sender: NSMenuItem) {
        let parents = targetURLs.map { $0.deletingLastPathComponent().path }
        guard !parents.isEmpty else { return fail() }
        var seen = Set<String>()
        copyToPasteboard(parents.filter { seen.insert($0).inserted }.joined(separator: "\n"))
    }

    @objc func copyFileURL(_ sender: NSMenuItem) { copyLines { $0.absoluteString } }

    @objc func copyContents(_ sender: NSMenuItem) {
        guard let url = targetURLs.first, isRegularFile(url) else { return fail() }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= 10_000_000 else { return fail() }
        do {
            copyToPasteboard(try String(contentsOf: url, encoding: .utf8))
        } catch {
            fail(error)
        }
    }

    @objc func copySHA256(_ sender: NSMenuItem) {
        let files = targetURLs.filter(isRegularFile)
        guard !files.isEmpty else { return fail() }
        DispatchQueue.global(qos: .userInitiated).async {
            // Сбой на одном файле не отменяет остальные: копируем то, что посчиталось.
            var failed = false
            let lines = files.compactMap { url -> String? in
                do {
                    let hash = try Self.sha256(of: url)
                    return files.count == 1 ? hash : "\(hash)  \(url.lastPathComponent)"
                } catch {
                    NSLog("FinderTools: %@", String(describing: error))
                    failed = true
                    return nil
                }
            }
            DispatchQueue.main.async {
                if !lines.isEmpty { self.copyToPasteboard(lines.joined(separator: "\n")) }
                if failed { self.fail() }
            }
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        // autoreleasepool обязателен: без него прочитанные куски живут до конца блока GCD
        // и память растёт до размера файла.
        while let chunk = try autoreleasepool(invoking: { try handle.read(upToCount: 1 << 20) }), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Открыть в приложении

    @objc func openInApp(_ sender: NSMenuItem) {
        guard OpenApp.all.indices.contains(sender.tag) else { return fail() }
        let app = OpenApp.all[sender.tag]
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else { return fail() }

        let urls: [URL]
        switch app.kind {
        case .terminal:
            // Терминал открываем в папке: выделенной или содержащей выделенный файл.
            let dirs = targetURLs.map { isFolder($0) ? $0 : $0.deletingLastPathComponent() }
            urls = Array(Set(dirs))
        case .editor:
            urls = targetURLs
        }
        guard !urls.isEmpty else { return fail() }

        NSWorkspace.shared.open(urls, withApplicationAt: appURL,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { DispatchQueue.main.async { self.fail(error) } }
        }
    }

    // MARK: - Прочее

    @objc func makeExecutable(_ sender: NSMenuItem) {
        let fm = FileManager.default
        for url in targetURLs where !isFolder(url) {
            do {
                let current = (try fm.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.int16Value ?? 0o644
                try fm.setAttributes([.posixPermissions: NSNumber(value: current | 0o111)], ofItemAtPath: url.path)
            } catch {
                fail(error)
            }
        }
    }

    @objc func createSymlink(_ sender: NSMenuItem) {
        for target in targetURLs {
            let dir = target.deletingLastPathComponent()
            let base = target.deletingPathExtension().lastPathComponent + " (ссылка)"
            let link = uniqueURL(in: dir, base: base, ext: target.pathExtension)
            do {
                try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
            } catch {
                fail(error)
            }
        }
    }
}

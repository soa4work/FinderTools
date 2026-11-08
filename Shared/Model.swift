import Foundation

// Этот файл компилируется и в приложение, и в расширение.

/// Шаблон для пункта «Новый файл».
struct FileTemplate: Identifiable {
    let id: String
    let title: String
    let baseName: String
    let ext: String
    let symbol: String
    let content: String
    var executable = false

    static let all: [FileTemplate] = [
        FileTemplate(id: "txt", title: "Текстовый файл (.txt)", baseName: "Без названия", ext: "txt",
                     symbol: "doc.text", content: ""),
        FileTemplate(id: "md", title: "Markdown (.md)", baseName: "Без названия", ext: "md",
                     symbol: "text.alignleft", content: "# Заголовок\n\n"),
        FileTemplate(id: "rtf", title: "Документ RTF (.rtf)", baseName: "Документ", ext: "rtf",
                     symbol: "doc.richtext", content: "{\\rtf1\\ansi\\ansicpg1251\\deff0\n}\n"),
        FileTemplate(id: "empty", title: "Пустой файл", baseName: "Новый файл", ext: "",
                     symbol: "doc", content: ""),
        FileTemplate(id: "json", title: "JSON (.json)", baseName: "data", ext: "json",
                     symbol: "curlybraces", content: "{\n  \n}\n"),
        FileTemplate(id: "yml", title: "YAML (.yml)", baseName: "config", ext: "yml",
                     symbol: "list.bullet.indent", content: ""),
        FileTemplate(id: "csv", title: "CSV (.csv)", baseName: "table", ext: "csv",
                     symbol: "tablecells", content: "column1,column2\n"),
        FileTemplate(id: "html", title: "HTML (.html)", baseName: "index", ext: "html",
                     symbol: "chevron.left.forwardslash.chevron.right",
                     content: """
                     <!doctype html>
                     <html lang="ru">
                     <head>
                       <meta charset="utf-8">
                       <meta name="viewport" content="width=device-width, initial-scale=1">
                       <title>Новая страница</title>
                     </head>
                     <body>

                     </body>
                     </html>

                     """),
        FileTemplate(id: "css", title: "CSS (.css)", baseName: "style", ext: "css",
                     symbol: "paintbrush", content: ""),
        FileTemplate(id: "js", title: "JavaScript (.js)", baseName: "script", ext: "js",
                     symbol: "j.square", content: ""),
        FileTemplate(id: "py", title: "Python (.py)", baseName: "script", ext: "py",
                     symbol: "p.square",
                     content: "#!/usr/bin/env python3\n\n\ndef main():\n    pass\n\n\nif __name__ == \"__main__\":\n    main()\n",
                     executable: true),
        FileTemplate(id: "swift", title: "Swift (.swift)", baseName: "main", ext: "swift",
                     symbol: "swift", content: "import Foundation\n\n"),
        FileTemplate(id: "sh", title: "Shell-скрипт (.sh)", baseName: "script", ext: "sh",
                     symbol: "terminal", content: "#!/bin/bash\nset -euo pipefail\n\n",
                     executable: true),
        FileTemplate(id: "gitignore", title: ".gitignore", baseName: ".gitignore", ext: "",
                     symbol: "eye.slash", content: ".DS_Store\n"),
    ]
}

/// Приложения для пункта «Открыть в». В меню показываются только установленные.
struct OpenApp: Identifiable {
    enum Kind { case terminal, editor }
    let title: String
    let bundleID: String
    let kind: Kind
    var id: String { bundleID }

    static let all: [OpenApp] = [
        OpenApp(title: "Терминал", bundleID: "com.apple.Terminal", kind: .terminal),
        OpenApp(title: "iTerm", bundleID: "com.googlecode.iterm2", kind: .terminal),
        OpenApp(title: "Warp", bundleID: "dev.warp.Warp-Stable", kind: .terminal),
        OpenApp(title: "Ghostty", bundleID: "com.mitchellh.ghostty", kind: .terminal),
        OpenApp(title: "Visual Studio Code", bundleID: "com.microsoft.VSCode", kind: .editor),
        OpenApp(title: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92", kind: .editor),
        OpenApp(title: "Zed", bundleID: "dev.zed.Zed", kind: .editor),
        OpenApp(title: "Sublime Text", bundleID: "com.sublimetext.4", kind: .editor),
        OpenApp(title: "Xcode", bundleID: "com.apple.dt.Xcode", kind: .editor),
    ]
}

/// Все пункты меню, которые можно включать и выключать.
enum MenuAction: String, CaseIterable, Identifiable {
    case newFile, newFromClipboard
    case copyPath, copyName, copyNameWithoutExtension, copyShellPath, copyTildePath,
         copyParentPath, copyFileURL, copyContents, copySHA256
    case openIn
    case makeExecutable, createSymlink

    enum Group: String, CaseIterable {
        case create = "Создание"
        case copy = "Копирование"
        case open = "Открытие"
        case more = "Ещё"
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newFile: return "Новый файл (по шаблонам)"
        case .newFromClipboard: return "Новый файл из буфера обмена"
        case .copyPath: return "Скопировать путь"
        case .copyName: return "Имя"
        case .copyNameWithoutExtension: return "Имя без расширения"
        case .copyShellPath: return "Путь для Терминала (в кавычках)"
        case .copyTildePath: return "Путь от ~"
        case .copyParentPath: return "Путь к родительской папке"
        case .copyFileURL: return "Ссылка file://"
        case .copyContents: return "Содержимое файла"
        case .copySHA256: return "SHA-256"
        case .openIn: return "Открыть в…"
        case .makeExecutable: return "Сделать исполняемым (chmod +x)"
        case .createSymlink: return "Создать символическую ссылку"
        }
    }

    var symbol: String {
        switch self {
        case .newFile: return "doc.badge.plus"
        case .newFromClipboard: return "doc.on.clipboard"
        case .copyPath: return "link"
        case .copyName: return "textformat"
        case .copyNameWithoutExtension: return "textformat.abc"
        case .copyShellPath: return "terminal"
        case .copyTildePath: return "house"
        case .copyParentPath: return "folder"
        case .copyFileURL: return "globe"
        case .copyContents: return "doc.plaintext"
        case .copySHA256: return "number"
        case .openIn: return "arrow.up.forward.app"
        case .makeExecutable: return "gearshape"
        case .createSymlink: return "arrowshape.turn.up.right"
        }
    }

    var group: Group {
        switch self {
        case .newFile, .newFromClipboard: return .create
        case .copyPath, .copyName, .copyNameWithoutExtension, .copyShellPath, .copyTildePath,
             .copyParentPath, .copyFileURL, .copyContents, .copySHA256: return .copy
        case .openIn: return .open
        case .makeExecutable, .createSymlink: return .more
        }
    }

    /// Пункт имеет смысл только при выделенных файлах (не по клику на пустом месте).
    var requiresSelection: Bool {
        switch self {
        case .copyContents, .copySHA256, .makeExecutable, .createSymlink: return true
        default: return false
        }
    }
}

/// Настройки. Хранятся «выключенные» элементы, поэтому новые пункты по умолчанию включены.
struct FinderToolsSettings: Codable, Equatable {
    var disabledActions: Set<String> = []
    var disabledTemplates: Set<String> = []
    var disabledApps: Set<String> = []
    /// Спрятать все пункты в одно подменю «FinderTools».
    var groupInSubmenu = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        disabledActions = try c.decodeIfPresent(Set<String>.self, forKey: .disabledActions) ?? []
        disabledTemplates = try c.decodeIfPresent(Set<String>.self, forKey: .disabledTemplates) ?? []
        disabledApps = try c.decodeIfPresent(Set<String>.self, forKey: .disabledApps) ?? []
        groupInSubmenu = try c.decodeIfPresent(Bool.self, forKey: .groupInSubmenu) ?? false
    }

    func isEnabled(_ action: MenuAction) -> Bool { !disabledActions.contains(action.rawValue) }
    func isEnabled(_ template: FileTemplate) -> Bool { !disabledTemplates.contains(template.id) }
    func isEnabled(_ app: OpenApp) -> Bool { !disabledApps.contains(app.bundleID) }
}

/// Общий файл настроек: ~/Library/Application Support/FinderTools/settings.json.
/// Приложение и расширение живут в разных песочницах, поэтому используется путь вне контейнеров,
/// доступ к которому выдан в entitlements обоих таргетов.
enum SettingsStorage {
    /// Настоящая домашняя папка (в песочнице NSHomeDirectory указывает на контейнер).
    static let realHome: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }()

    static var fileURL: URL {
        URL(fileURLWithPath: realHome)
            .appendingPathComponent("Library/Application Support/FinderTools", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static func load() -> FinderToolsSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(FinderToolsSettings.self, from: data) else {
            return FinderToolsSettings()
        }
        return settings
    }

    static func save(_ settings: FinderToolsSettings) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: fileURL, options: .atomic)
    }
}

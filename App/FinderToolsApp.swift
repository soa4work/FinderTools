import AppKit
import FinderSync
import SwiftUI

@main
struct FinderToolsApp: App {
    @StateObject private var store = SettingsStore()

    var body: some Scene {
        Window("FinderTools", id: "main") {
            SettingsView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Хранилище настроек

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: FinderToolsSettings {
        didSet {
            guard settings != oldValue else { return }
            do {
                try SettingsStorage.save(settings)
                saveError = nil
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
    @Published var saveError: String?

    init() { settings = SettingsStorage.load() }

    /// Binding «включено» для элемента, который хранится в наборе выключенных.
    func isOn(_ keyPath: WritableKeyPath<FinderToolsSettings, Set<String>>, _ id: String) -> Binding<Bool> {
        Binding(
            get: { !self.settings[keyPath: keyPath].contains(id) },
            set: { on in
                if on { self.settings[keyPath: keyPath].remove(id) }
                else { self.settings[keyPath: keyPath].insert(id) }
            }
        )
    }

    func setAll(_ keyPath: WritableKeyPath<FinderToolsSettings, Set<String>>, ids: [String], on: Bool) {
        if on { settings[keyPath: keyPath].subtract(ids) } else { settings[keyPath: keyPath].formUnion(ids) }
    }

    func reset() { settings = FinderToolsSettings() }
}

// MARK: - Окно

struct SettingsView: View {
    var body: some View {
        TabView {
            MenuTab().tabItem { Label("Меню", systemImage: "contextualmenu.and.cursorarrow") }
            TemplatesTab().tabItem { Label("Шаблоны", systemImage: "doc.badge.plus") }
            AppsTab().tabItem { Label("Приложения", systemImage: "arrow.up.forward.app") }
            StatusTab().tabItem { Label("Расширение", systemImage: "puzzlepiece.extension") }
        }
        .frame(width: 520, height: 560)
        .padding(.top, 8)
    }
}

struct MenuTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Спрятать все пункты в подменю «FinderTools»", isOn: $store.settings.groupInSubmenu)
            } footer: {
                Text("Контекстное меню Finder станет короче. На кнопку в панели инструментов не влияет.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(MenuAction.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(MenuAction.allCases.filter { $0.group == group }) { action in
                        Toggle(isOn: store.isOn(\.disabledActions, action.rawValue)) {
                            Label(action.title, systemImage: action.symbol)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Включить всё") {
                        store.setAll(\.disabledActions, ids: MenuAction.allCases.map(\.rawValue), on: true)
                    }
                    Spacer()
                    Button("Сбросить все настройки", role: .destructive) { store.reset() }
                }
                if let error = store.saveError {
                    Text("Не удалось сохранить: \(error)").foregroundStyle(.red).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct TemplatesTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            if !store.settings.isEnabled(.newFile) {
                Text("Пункт «Новый файл» выключен на вкладке «Меню», поэтому шаблоны сейчас не показываются.")
                    .foregroundStyle(.orange)
            }
            Section("Шаблоны в подменю «Новый файл»") {
                ForEach(FileTemplate.all) { template in
                    Toggle(isOn: store.isOn(\.disabledTemplates, template.id)) {
                        Label(template.title, systemImage: template.symbol)
                    }
                }
            }
            Section {
                HStack {
                    Button("Включить все") {
                        store.setAll(\.disabledTemplates, ids: FileTemplate.all.map(\.id), on: true)
                    }
                    Button("Выключить все") {
                        store.setAll(\.disabledTemplates, ids: FileTemplate.all.map(\.id), on: false)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AppsTab: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            if !store.settings.isEnabled(.openIn) {
                Text("Пункт «Открыть в…» выключен на вкладке «Меню».")
                    .foregroundStyle(.orange)
            }
            Section("Приложения в подменю «Открыть в»") {
                ForEach(OpenApp.all) { app in
                    let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
                    Toggle(isOn: store.isOn(\.disabledApps, app.bundleID)) {
                        HStack {
                            if let appURL {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable().frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "questionmark.app.dashed")
                                    .frame(width: 18, height: 18)
                            }
                            Text(app.title)
                            if appURL == nil {
                                Text("не установлено").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(appURL == nil)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct StatusTab: View {
    @State private var enabled = FIFinderSyncController.isExtensionEnabled
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("FinderTools").font(.title.bold())
                    Text("Полезные пункты в контекстном меню Finder").foregroundStyle(.secondary)
                }
            }

            HStack {
                Circle().fill(enabled ? Color.green : Color.orange).frame(width: 10, height: 10)
                Text(enabled ? "Расширение включено" : "Расширение выключено").font(.headline)
            }

            if !enabled {
                Text("Включите FinderTools в Системных настройках → Основные → Объекты входа и расширения (на macOS 13–14: Конфиденциальность и безопасность → Расширения → Добавленные расширения).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Открыть настройки расширений") {
                FIFinderSyncController.showExtensionManagementInterface()
            }
            .buttonStyle(.borderedProminent)

            Divider()

            Text("Изменения применяются сразу, перезапускать Finder не нужно.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Text("Файл настроек:").font(.callout)
                Button(SettingsStorage.fileURL.path.replacingOccurrences(of: SettingsStorage.realHome, with: "~")) {
                    NSWorkspace.shared.activateFileViewerSelecting([SettingsStorage.fileURL])
                }
                .buttonStyle(.link)
                .font(.callout)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in enabled = FIFinderSyncController.isExtensionEnabled }
    }
}

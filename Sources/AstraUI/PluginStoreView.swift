import SwiftUI
import AppKit
import AstraCore

struct PluginStoreView: View {
    let plugins: [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void
    let installPluginAction: (PluginManifest, Data) async throws -> Void
    let removePluginAction: (String) async throws -> Void

    @State private var isShowingInstallSheet = false
    @State private var pluginToRemove: InstalledPlugin?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plugins")
                    .font(.headline)
                Spacer()
                Button("Install Plugin…") {
                    errorMessage = nil
                    isShowingInstallSheet = true
                }
                .buttonStyle(.bordered)
            }

            if plugins.isEmpty {
                Text("No plugins installed")
                    .foregroundStyle(.secondary)
            } else {
                List(plugins, id: \.manifest.pluginId) { plugin in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(plugin.manifest.displayName)
                            Text(plugin.manifest.version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle(
                            "Enabled",
                            isOn: Binding(
                                get: { plugin.isEnabled },
                                set: { newValue in
                                    Task {
                                        try? await setPluginEnabledAction(plugin.manifest.pluginId, newValue)
                                    }
                                }
                            )
                        )
                        .labelsHidden()

                        Button(role: .destructive) {
                            pluginToRemove = plugin
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(minHeight: 180)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $isShowingInstallSheet) {
            InstallPluginSheet(
                installAction: { manifest, bundleData in
                    try await installPluginAction(manifest, bundleData)
                }
            )
        }
        .alert(
            "Remove Plugin?",
            isPresented: Binding(
                get: { pluginToRemove != nil },
                set: { isPresented in
                    if !isPresented {
                        pluginToRemove = nil
                    }
                }
            ),
            presenting: pluginToRemove
        ) { plugin in
            Button("Remove", role: .destructive) {
                Task {
                    do {
                        try await removePluginAction(plugin.manifest.pluginId)
                    } catch {
                        errorMessage = "Failed to remove plugin: \(String(describing: error))"
                    }
                    pluginToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pluginToRemove = nil
            }
        } message: { plugin in
            Text("\"\(plugin.manifest.displayName)\" will be uninstalled and its data removed. This cannot be undone.")
        }
    }
}

private struct InstallPluginSheet: View {
    let installAction: (PluginManifest, Data) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pluginId = ""
    @State private var displayName = ""
    @State private var version = ""
    @State private var capabilitiesText = ""
    @State private var bundleURL: URL?
    @State private var errorMessage: String?
    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install Plugin")
                .font(.title3)
                .bold()

            TextField("Plugin ID (e.g. com.example.tool)", text: $pluginId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)

            TextField("Display Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)

            TextField("Version (e.g. 1.0.0)", text: $version)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)

            TextField("Capabilities (comma-separated, optional)", text: $capabilitiesText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)

            HStack {
                Button("Choose Bundle File…") {
                    chooseBundleFile()
                }
                .buttonStyle(.bordered)

                if let bundleURL {
                    Text(bundleURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Install") {
                    Task {
                        await submitInstall()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)
            }
        }
        .padding()
        .frame(minWidth: 380)
    }

    private func chooseBundleFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            bundleURL = panel.url
        }
    }

    private func submitInstall() async {
        errorMessage = nil

        let trimmedId = pluginId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty, !trimmedName.isEmpty, !trimmedVersion.isEmpty else {
            errorMessage = "Plugin ID, Display Name, and Version are required."
            return
        }
        guard let bundleURL else {
            errorMessage = "Choose a bundle file to install."
            return
        }

        let capabilities = capabilitiesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        isInstalling = true
        defer { isInstalling = false }

        do {
            let bundleData = try Data(contentsOf: bundleURL)
            let manifest = PluginManifest(
                pluginId: trimmedId,
                displayName: trimmedName,
                version: trimmedVersion,
                capabilities: capabilities
            )
            try await installAction(manifest, bundleData)
            dismiss()
        } catch {
            errorMessage = mapInstallError(error)
        }
    }

    private func mapInstallError(_ error: Error) -> String {
        switch error {
        case PluginServiceError.invalidManifest:
            return "Plugin ID, Display Name, and Version cannot be empty."
        case PluginServiceError.invalidBundle:
            return "The chosen file is empty or could not be read as a plugin bundle."
        case PluginServiceError.pluginAlreadyInstalled:
            return "A plugin with this ID is already installed."
        default:
            return "Install failed: \(String(describing: error))"
        }
    }
}

import SwiftUI
import AstraCore

struct PluginStoreView: View {
    let plugins: [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugins")
                .font(.headline)

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
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }
}

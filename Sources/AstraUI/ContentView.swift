import SwiftUI
import AstraCore

struct ContentView: View {
    @StateObject private var env = AppEnvironment()
    @State private var didInitializeCoordinator = false
    @State private var sessionState: AppCoordinator.SessionState = .locked
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch sessionState {
            case .firstLaunchSetup:
                UnlockView(
                    coordinator: env.coordinator,
                    createAction: { passphrase in
                        try await env.coordinator.createInitialPassphraseAndUnlock(passphrase)
                    },
                    unlockAction: { passphrase in
                        try await env.coordinator.unlock(passphrase: passphrase)
                    },
                    biometricUnlockAction: {
                        try await env.coordinator.unlockWithBiometrics()
                    }
                )
            case .locked, .unlocked:
                NotesWorkspaceView(
                    searchAction: { query in
                        return await env.noteSearchService.searchTitle(query: query, isUnlocked: true)
                    },
                    listNotesAction: {
                        return await env.noteService.listSummaries()
                    },
                    loadNoteAction: { noteId in
                        return try await env.noteService.load(id: noteId)
                    },
                    saveDraftAction: { draft in
                        try await env.noteService.save(draft: draft)
                    },
                    updateSecureMetadataAction: { noteId, alias, subjectId in
                        try await env.noteService.updateSecureMetadata(noteId: noteId, secureTitleAlias: alias, subjectId: subjectId)
                    },
                    deleteNoteAction: { noteId in
                        try await env.noteService.delete(noteId: noteId)
                    },
                    addImageAttachmentAction: { noteId, storagePath, byteSize in
                        try await env.noteService.addImageAttachment(noteId: noteId, storagePath: storagePath, byteSize: byteSize)
                    },
                    addVoiceAttachmentAction: { noteId, storagePath, byteSize in
                        try await env.noteService.addVoiceAttachment(noteId: noteId, storagePath: storagePath, byteSize: byteSize)
                    },
                    listAttachmentsAction: { noteId in
                        await env.noteService.listAttachments(noteId: noteId)
                    },
                    listSubjectsAction: {
                        await env.subjectService.list()
                    },
                    createSubjectAction: { name in
                        try await env.subjectService.create(name: name)
                    },
                    deleteSubjectAction: { subjectId in
                        try await env.subjectService.delete(id: subjectId)
                    },
                    listTrashAction: {
                        await env.trashService.listTrashItems()
                    },
                    restoreTrashAction: { trashId in
                        try await env.trashService.restore(trashId: trashId)
                    },
                    permanentlyDeleteTrashAction: { trashId in
                        try await env.trashService.permanentlyDelete(trashId: trashId)
                    },
                    secureTrashPreviewAction: { trashId in
                        try await env.trashService.secureTitlePreviewMessage(trashId: trashId)
                    },
                    secureNotePassphraseAuthAction: { passphrase in
                        try await env.coordinator.reauthenticateForSecureNote(passphrase: passphrase)
                    },
                    secureNoteBiometricAuthAction: {
                        try await env.coordinator.reauthenticateForSecureNoteWithBiometrics()
                    },
                    loadSettingsAction: {
                        await env.settingsService.load()
                    },
                    saveSettingsAction: { settings in
                        try await env.settingsService.update(
                            lockTimeoutSeconds: settings.lockTimeoutSeconds,
                            telemetryEnabled: settings.telemetryEnabled,
                            pluginsEnabled: settings.pluginsEnabled,
                            biometricUnlockEnabled: settings.biometricUnlockEnabled
                        )
                    },
                    updateBiometricAction: { isEnabled in
                        try await env.coordinator.updateBiometricUnlock(enabled: isEnabled)
                    },
                    installedPluginsAction: {
                        await env.pluginService.listInstalled()
                    },
                    setPluginEnabledAction: { pluginId, isEnabled in
                        try await env.pluginService.setEnabled(pluginId: pluginId, isEnabled: isEnabled)
                    },
                    userInteractionAction: {
                        env.coordinator.registerUserInteraction(now: Date())
                    }
                )
            }
        }
        .task {
            guard !didInitializeCoordinator else {
                return
            }
            didInitializeCoordinator = true
            await env.coordinator.start()
            sessionState = env.coordinator.sessionState
            env.coordinator.bind(platformIntegration: env.platformIntegration)
        }
        .onReceive(env.coordinator.$sessionState) { updatedState in
            sessionState = updatedState
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await env.coordinator.evaluateInactivityAutoLock(now: Date())
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                switch newPhase {
                case .active:
                    env.coordinator.registerUserInteraction(now: Date())
                default:
                    break
                }
            }
        }
    }
}

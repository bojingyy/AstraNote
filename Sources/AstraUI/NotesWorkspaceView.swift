import SwiftUI
import AstraCore

struct NotesWorkspaceView: View {
    let searchAction: (String) async -> [NoteSearchResult]
    let listNotesAction: () async -> [NoteSummary]
    let loadNoteAction: (UUID) async throws -> NoteView
    let saveDraftAction: (NoteDraft) async throws -> UUID
    let deleteNoteAction: (UUID) async throws -> Bool
    let listSubjectsAction: () async -> [Subject]
    let createSubjectAction: (String) async throws -> Subject
    let deleteSubjectAction: (UUID) async throws -> Bool
    let listTrashAction: () async -> [TrashItemView]
    let restoreTrashAction: (UUID) async throws -> Bool
    let permanentlyDeleteTrashAction: (UUID) async throws -> Bool
    let secureTrashPreviewAction: (UUID) async throws -> String?
    let secureNotePassphraseAuthAction: (String) async throws -> Void
    let secureNoteBiometricAuthAction: (() async throws -> Void)?
    let lockAction: () async -> Void
    let loadSettingsAction: () async -> AppSettings
    let saveSettingsAction: (AppSettings) async throws -> Void
    let updateBiometricAction: (Bool) async throws -> Void
    let installedPluginsAction: () async -> [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void

    @State private var query = ""
    @State private var searchResults: [NoteSearchResult] = []
    @State private var notes: [NoteSummary] = []
    @State private var subjects: [Subject] = []
    @State private var selectedSubjectId: UUID?
    @State private var selectedNoteId: UUID?
    @State private var title = ""
    @State private var content = ""
    @State private var secureModeEnabled = false
    @State private var expirationDate = Date()
    @State private var expirationTime = Date()
    @State private var editorSubjectId: UUID?
    @State private var newSubjectName = ""
    @State private var isShowingTrash = false
    @State private var trashItems: [TrashItemView] = []
    @State private var pendingSubjectDeletion: Subject?
    @State private var isShowingSettings = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var collapsedGroupIDs: Set<String> = []
    @State private var isShowingSecureAccessPrompt = false
    @State private var pendingSecureNoteId: UUID?
    @State private var secureAccessPassphrase = ""
    @State private var secureAccessErrorMessage: String?

    private struct NoteListItem: Identifiable {
        let id: UUID
        let title: String
        let isSecure: Bool
        let subjectId: UUID?
    }

    private struct SubjectGroup: Identifiable {
        let subjectId: UUID?
        let name: String
        let canDelete: Bool

        var id: String {
            subjectId?.uuidString ?? "ungrouped"
        }
    }

    private var displayedNotes: [NoteListItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return searchResults.map { result in
                let subjectId = notes.first(where: { $0.id == result.noteId })?.subjectId
                return NoteListItem(
                    id: result.noteId,
                    title: result.matchedTitle,
                    isSecure: result.isSecure,
                    subjectId: subjectId
                )
            }
        }

        return notes.map { summary in
            NoteListItem(
                id: summary.id,
                title: summary.title,
                isSecure: summary.isSecure,
                subjectId: summary.subjectId
            )
        }
    }

    private var subjectGroups: [SubjectGroup] {
        var groups = [SubjectGroup(subjectId: nil, name: "Ungrouped", canDelete: false)]
        groups.append(contentsOf: subjects.map { subject in
            SubjectGroup(subjectId: subject.id, name: subject.name, canDelete: true)
        })

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return groups
        }

        return groups.filter { group in
            displayedNotes.contains { $0.subjectId == group.subjectId }
        }
    }

    private func notesForGroup(_ subjectId: UUID?) -> [NoteListItem] {
        displayedNotes.filter { $0.subjectId == subjectId }
    }

    private func groupID(for subjectId: UUID?) -> String {
        subjectId?.uuidString ?? "ungrouped"
    }

    private func isGroupCollapsed(_ group: SubjectGroup) -> Bool {
        collapsedGroupIDs.contains(group.id)
    }

    private func toggleGroupCollapse(_ group: SubjectGroup) {
        if collapsedGroupIDs.contains(group.id) {
            collapsedGroupIDs.remove(group.id)
        } else {
            collapsedGroupIDs.insert(group.id)
        }
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Search note titles", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task {
                                await performSearch()
                            }
                        }
                    Button("Search") {
                        Task {
                            await performSearch()
                        }
                    }
                    Button("Reset") {
                        Task {
                            query = ""
                            searchResults = []
                            await refreshWorkspace()
                        }
                    }
                }

                HStack {
                    Button("New Note") {
                        clearEditorForNewNote()
                    }
                    Button("Trash Can") {
                        Task {
                            await loadTrashItems()
                            isShowingTrash = true
                        }
                    }
                    Button("Lock AstraNote") {
                        Task {
                            await lockAction()
                        }
                    }
                    Button("Settings") {
                        isShowingSettings = true
                    }
                }

                Divider()

                Text("Subjects & Notes")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(subjectGroups) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Button {
                                        toggleGroupCollapse(group)
                                    } label: {
                                        Image(systemName: isGroupCollapsed(group) ? "chevron.right" : "chevron.down")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)

                                    Text(group.name)
                                    Spacer()

                                    if group.canDelete, let subjectId = group.subjectId,
                                       let subject = subjects.first(where: { $0.id == subjectId }) {
                                        Button("Delete") {
                                            let subjectHasNotes = notes.contains { $0.subjectId == subject.id }
                                            if subjectHasNotes {
                                                pendingSubjectDeletion = subject
                                            } else {
                                                Task {
                                                    await deleteSubject(subject)
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.clear)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSubjectId = group.subjectId
                                }

                                if !isGroupCollapsed(group) {
                                    ForEach(notesForGroup(group.subjectId)) { note in
                                        HStack {
                                            Text(note.isSecure ? "[Secure]" : "[Normal]")
                                            Text(note.title)
                                            Spacer(minLength: 0)
                                        }
                                        .font(.subheadline)
                                        .padding(.leading, 24)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedNoteId == note.id ? Color.accentColor.opacity(0.14) : Color.clear)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            Task {
                                                await requestOpenNote(note)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                HStack {
                    TextField("New subject", text: $newSubjectName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        Task {
                            do {
                                _ = try await createSubjectAction(newSubjectName)
                                newSubjectName = ""
                                await refreshWorkspace()
                            } catch {
                                errorMessage = mapError(error)
                            }
                        }
                    }
                }

                Divider()
            }
            .padding()
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedNoteId == nil ? "Create Note" : "Edit Note")
                    .font(.title2)
                    .bold()

                TextField("Title", text: $title)
                    .font(.system(size: 16))
                    .textFieldStyle(.roundedBorder)

                Picker("Subject", selection: $editorSubjectId) {
                    Text("Ungrouped").tag(Optional<UUID>.none)
                    ForEach(subjects, id: \.id) { subject in
                        Text(subject.name).tag(Optional(subject.id))
                    }
                }

                Toggle("Secure mode", isOn: $secureModeEnabled)

                if secureModeEnabled {
                    HStack {
                        DatePicker(
                            "Expiration Date",
                            selection: $expirationDate,
                            displayedComponents: [.date]
                        )
                        DatePicker(
                            "Expiration Time",
                            selection: $expirationTime,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                }

                ZStack {
                    TextEditor(text: $content)
                        .font(.system(size: 16))
                        .padding(.top, 6)
                        .padding(.horizontal, 4)
                }
                .frame(minHeight: 240)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.4))
                }

                if let infoMessage {
                    Text(infoMessage)
                        .foregroundStyle(.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Save") {
                        Task {
                            await saveCurrentDraft()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Delete") {
                        Task {
                            await deleteSelectedNote()
                        }
                    }
                    .disabled(selectedNoteId == nil)

                    Button("New") {
                        clearEditorForNewNote()
                    }
                }

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                loadSettingsAction: loadSettingsAction,
                saveSettingsAction: saveSettingsAction,
                updateBiometricAction: updateBiometricAction,
                installedPluginsAction: installedPluginsAction,
                setPluginEnabledAction: setPluginEnabledAction
            )
        }
        .sheet(isPresented: $isShowingTrash) {
            NavigationStack {
                List(trashItems, id: \.trashId) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.isSecure ? "[Secure] Locked Note" : (item.displayTitle ?? "Untitled"))
                            .font(.headline)
                        Text("Deleted: \(item.deletionTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            if item.isSecure {
                                Button("Why Locked?") {
                                    Task {
                                        do {
                                            infoMessage = try await secureTrashPreviewAction(item.trashId)
                                        } catch {
                                            errorMessage = mapError(error)
                                        }
                                    }
                                }
                            }

                            Button("Restore") {
                                Task {
                                    do {
                                        _ = try await restoreTrashAction(item.trashId)
                                        await loadTrashItems()
                                        await refreshWorkspace()
                                    } catch {
                                        errorMessage = mapError(error)
                                    }
                                }
                            }

                            Button("Delete Permanently") {
                                Task {
                                    do {
                                        _ = try await permanentlyDeleteTrashAction(item.trashId)
                                        await loadTrashItems()
                                    } catch {
                                        errorMessage = mapError(error)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Protected Trash")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isShowingTrash = false
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 420)
        }
        .sheet(isPresented: $isShowingSecureAccessPrompt) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Unlock Secure Note")
                    .font(.title2)
                    .bold()

                Text("Enter your passphrase or use biometrics to open this secure note.")
                    .foregroundStyle(.secondary)

                SecureField("Passphrase", text: $secureAccessPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)

                if let secureAccessErrorMessage {
                    Text(secureAccessErrorMessage)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Cancel", role: .cancel) {
                        pendingSecureNoteId = nil
                        secureAccessPassphrase = ""
                        secureAccessErrorMessage = nil
                        isShowingSecureAccessPrompt = false
                    }

                    if let secureNoteBiometricAuthAction {
                        Button("Use Biometrics") {
                            Task {
                                await authenticatePendingSecureNoteWithBiometrics(action: secureNoteBiometricAuthAction)
                            }
                        }
                    }

                    Button("Unlock") {
                        Task {
                            await authenticatePendingSecureNoteWithPassphrase()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 420)
        }
        .task {
            await refreshWorkspace()
        }
        .alert("Delete Subject?", isPresented: Binding(
            get: { pendingSubjectDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingSubjectDeletion = nil
                }
            }
        ), presenting: pendingSubjectDeletion) { subject in
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSubject(subject)
                    pendingSubjectDeletion = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSubjectDeletion = nil
            }
        } message: { subject in
            Text("\(subject.name) contains notes. Deleting the subject will ungroup those notes.")
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
            return
        }
        searchResults = await searchAction(trimmed)
    }

    private func refreshWorkspace() async {
        notes = await listNotesAction()
        subjects = await listSubjectsAction()
        await performSearch()

        if let selectedNoteId, !notes.map(\.id).contains(selectedNoteId) {
            clearEditorForNewNote()
        }
    }

    private func loadTrashItems() async {
        trashItems = await listTrashAction()
    }

    private func requestOpenNote(_ note: NoteListItem) async {
        if note.isSecure {
            pendingSecureNoteId = note.id
            secureAccessPassphrase = ""
            secureAccessErrorMessage = nil
            isShowingSecureAccessPrompt = true
            return
        }

        await selectNote(note.id)
    }

    private func selectNote(_ noteId: UUID) async {
        do {
            let loaded = try await loadNoteAction(noteId)
            selectedNoteId = loaded.id
            selectedSubjectId = loaded.subjectId
            collapsedGroupIDs.remove(groupID(for: loaded.subjectId))
            title = loaded.title
            content = loaded.content
            secureModeEnabled = loaded.isSecure
            editorSubjectId = loaded.subjectId

            if let expiration = loaded.expirationUTC {
                expirationDate = expiration
                expirationTime = expiration
            } else {
                let defaultFuture = Date().addingTimeInterval(3600)
                expirationDate = defaultFuture
                expirationTime = defaultFuture
            }
            errorMessage = nil
            infoMessage = nil
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func authenticatePendingSecureNoteWithPassphrase() async {
        guard let pendingSecureNoteId else {
            return
        }

        do {
            secureAccessErrorMessage = nil
            try await secureNotePassphraseAuthAction(secureAccessPassphrase)
            await selectNote(pendingSecureNoteId)
            secureAccessPassphrase = ""
            self.pendingSecureNoteId = nil
            isShowingSecureAccessPrompt = false
        } catch {
            secureAccessErrorMessage = mapError(error)
        }
    }

    private func authenticatePendingSecureNoteWithBiometrics(action: () async throws -> Void) async {
        guard let pendingSecureNoteId else {
            return
        }

        do {
            secureAccessErrorMessage = nil
            try await action()
            await selectNote(pendingSecureNoteId)
            secureAccessPassphrase = ""
            self.pendingSecureNoteId = nil
            isShowingSecureAccessPrompt = false
        } catch {
            secureAccessErrorMessage = mapError(error)
        }
    }

    private func saveCurrentDraft() async {
        do {
            let expirationUTC = secureModeEnabled ? combineExpiration(datePart: expirationDate, timePart: expirationTime) : nil
            let draft = NoteDraft(
                id: selectedNoteId,
                title: title,
                content: content,
                subjectId: editorSubjectId,
                secureModeEnabled: secureModeEnabled,
                expirationUTC: expirationUTC
            )

            let savedId = try await saveDraftAction(draft)
            selectedNoteId = savedId
            infoMessage = "Note saved."
            errorMessage = nil
            await refreshWorkspace()
            await selectNote(savedId)
        } catch {
            errorMessage = mapError(error)
            infoMessage = nil
        }
    }

    private func deleteSelectedNote() async {
        guard let selectedNoteId else {
            return
        }

        do {
            _ = try await deleteNoteAction(selectedNoteId)
            clearEditorForNewNote()
            infoMessage = "Note moved to protected trash."
            errorMessage = nil
            await refreshWorkspace()
        } catch {
            errorMessage = mapError(error)
            infoMessage = nil
        }
    }

    private func deleteSubject(_ subject: Subject) async {
        do {
            _ = try await deleteSubjectAction(subject.id)
            if selectedSubjectId == subject.id {
                selectedSubjectId = nil
            }
            infoMessage = "Subject deleted; notes are now ungrouped."
            errorMessage = nil
            await refreshWorkspace()
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func clearEditorForNewNote() {
        selectedNoteId = nil
        title = ""
        content = ""
        secureModeEnabled = false
        editorSubjectId = selectedSubjectId
        let defaultFuture = Date().addingTimeInterval(3600)
        expirationDate = defaultFuture
        expirationTime = defaultFuture
        errorMessage = nil
        infoMessage = nil
    }

    private func combineExpiration(datePart: Date, timePart: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: datePart)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timePart)

        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = 0

        return calendar.date(from: merged) ?? datePart
    }

    private func mapError(_ error: Error) -> String {
        switch error {
        case NoteServiceError.titleRequired:
            return "Title is required."
        case NoteServiceError.secureModeRequiresExpiration:
            return "Secure mode requires expiration date and time."
        case NoteServiceError.secureModeExpirationInPast:
            return "Expiration must be in the future."
        case NoteServiceError.recordNotFound:
            return "The selected note was not found."
        case SubjectServiceError.emptyName:
            return "Subject name cannot be empty."
        case SubjectServiceError.duplicateName:
            return "Subject name must be unique."
        case ProtectedTrashServiceError.restoreRequiresUnlockedSession:
            return "Unlock AstraNotes to restore secure notes from trash."
        case KeyManagerError.invalidPassphrase:
            return "Invalid passphrase. Please try again."
        case KeyManagerError.lockoutActive(let remainingSeconds):
            return "Too many attempts. Try again in \(remainingSeconds) seconds."
        case KeyManagerError.passphraseNotInitialized:
            return "No passphrase found. Please restart and create a passphrase."
        case AppCoordinatorError.biometricUnavailable:
            return "Biometric authentication is unavailable on this device."
        case AppCoordinatorError.biometricUnlockDisabled:
            return "Biometric unlock is disabled. Use passphrase or enable biometrics in Settings."
        default:
            return String(describing: error)
        }
    }
}

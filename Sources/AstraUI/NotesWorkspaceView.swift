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

    private struct NoteListItem: Identifiable {
        let id: UUID
        let title: String
        let isSecure: Bool
    }

    private var displayedNotes: [NoteListItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return searchResults.map { result in
                NoteListItem(id: result.noteId, title: result.matchedTitle, isSecure: result.isSecure)
            }
        }

        let filtered = notes.filter { summary in
            selectedSubjectId == nil || summary.subjectId == selectedSubjectId
        }
        return filtered.map { summary in
            NoteListItem(id: summary.id, title: summary.title, isSecure: summary.isSecure)
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

                Text("Subjects")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            selectedSubjectId = nil
                        } label: {
                            HStack {
                                Text("All Notes")
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedSubjectId == nil ? Color.accentColor.opacity(0.18) : Color.clear)
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(subjects, id: \.id) { subject in
                            HStack {
                                Button {
                                    selectedSubjectId = subject.id
                                } label: {
                                    HStack {
                                        Text(subject.name)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedSubjectId == subject.id ? Color.accentColor.opacity(0.18) : Color.clear)
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

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
                    }
                }
                .frame(maxHeight: 160)

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

                Text("Notes")
                    .font(.headline)

                List(displayedNotes) { note in
                    HStack {
                        Text(note.isSecure ? "[Secure]" : "[Normal]")
                        Text(note.title)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            await selectNote(note.id)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedNoteId == note.id ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                }
            }
            .padding()
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedNoteId == nil ? "Create Note" : "Edit Note")
                    .font(.title2)
                    .bold()

                TextField("Title", text: $title)
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

    private func selectNote(_ noteId: UUID) async {
        do {
            let loaded = try await loadNoteAction(noteId)
            selectedNoteId = loaded.id
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
        default:
            return String(describing: error)
        }
    }
}

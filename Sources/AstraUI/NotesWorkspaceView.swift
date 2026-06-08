import SwiftUI
import AstraCore
import AppKit

struct NotesWorkspaceView: View {
    let searchAction: (String) async -> [NoteSearchResult]
    let listNotesAction: () async -> [NoteSummary]
    let loadNoteAction: (UUID) async throws -> NoteView
    let saveDraftAction: (NoteDraft) async throws -> UUID
    let updateSecureMetadataAction: (UUID, String?, UUID?) async throws -> Void
    let deleteNoteAction: (UUID) async throws -> Bool
    let addImageAttachmentAction: (UUID, String, Int) async throws -> UUID
    let addVoiceAttachmentAction: (UUID, String, Int) async throws -> UUID
    let listAttachmentsAction: (UUID) async -> [Attachment]
    let deleteAttachmentAction: (UUID, UUID) async throws -> Void
    let listSubjectsAction: () async -> [Subject]
    let createSubjectAction: (String) async throws -> Subject
    let deleteSubjectAction: (UUID) async throws -> Bool
    let listTrashAction: () async -> [TrashItemView]
    let restoreTrashAction: (UUID) async throws -> Bool
    let permanentlyDeleteTrashAction: (UUID) async throws -> Bool
    let secureTrashPreviewAction: (UUID) async throws -> String?
    let secureNotePassphraseAuthAction: (String) async throws -> Void
    let secureNoteBiometricAuthAction: (() async throws -> Void)?
    let loadSettingsAction: () async -> AppSettings
    let saveSettingsAction: (AppSettings) async throws -> Void
    let updateBiometricAction: (Bool) async throws -> Void
    let installedPluginsAction: () async -> [InstalledPlugin]
    let setPluginEnabledAction: (String, Bool) async throws -> Void
    let installPluginAction: (PluginManifest, Data) async throws -> Void
    let removePluginAction: (String) async throws -> Void
    let changePassphraseAction: (String, String) async throws -> Void
    let exportArchiveAction: () async throws -> Data
    let importArchiveAction: (Data) async throws -> ImportResult
    let userInteractionAction: () -> Void

    @State private var query = ""
    @State private var searchResults: [NoteSearchResult] = []
    @State private var notes: [NoteSummary] = []
    @State private var subjects: [Subject] = []
    @State private var selectedSubjectId: UUID?
    @State private var selectedNoteId: UUID?
    @State private var isComposingNewNote = false
    @State private var title = ""
    @State private var content = ""
    @State private var loadedTitleSnapshot = ""
    @State private var loadedContentSnapshot = ""
    @State private var loadedSubjectIdSnapshot: UUID?
    @State private var loadedSecureModeSnapshot = false
    @State private var loadedSecureAliasSnapshot = ""
    @State private var secureModeEnabled = false
    @State private var secureTitleAlias = ""
    @State private var editorFontSize: Double = 16
    @State private var editorTextColor: Color = .black
    @State private var editorTextColorKey = "black"
    @State private var editorApplyStyleRevision = 0
    @State private var editorIsBold = false
    @State private var editorIsItalic = false
    @State private var editorIsUnderlined = false
    @State private var editorSubjectId: UUID?
    @State private var newSubjectName = ""
    @State private var isShowingTrash = false
    @State private var trashItems: [TrashItemView] = []
    @State private var pendingSubjectDeletion: Subject?
    @State private var isShowingSettings = false
    @State private var collapsedGroupIDs: Set<String> = []
    @State private var isLeftPanelCollapsed = false
    @State private var attachments: [Attachment] = []
    @State private var isShowingSecureAccessPrompt = false
    @State private var pendingSecureAccessAction: SecureAccessAction?
    @State private var secureAccessPassphrase = ""
    @State private var toasts: [ToastMessage] = []
    @StateObject private var recordingController = AudioRecordingController()
    @State private var leftPanelWidth: CGFloat = 0
    @State private var dragStartWidth: CGFloat? = nil
    @State private var loadedUpdatedAt: Date? = nil

    private enum SecureAccessAction {
        case openSecureNote(UUID)
        case saveSecureDraft
        case continueAttachment(PendingAttachmentAction)
    }

    private enum PendingAttachmentAction {
        case importImage(URL)
        case finalizeRecording(storagePath: String, byteSize: Int)
    }

    private struct NoteListItem: Identifiable {
        let id: UUID
        let title: String
        let isSecure: Bool
        let subjectId: UUID?
        let updatedAt: Date?
    }

    private struct SubjectGroup: Identifiable {
        let subjectId: UUID?
        let name: String
        let canDelete: Bool

        var id: String {
            subjectId?.uuidString ?? "ungrouped"
        }
    }

    private struct ToastMessage: Identifiable {
        enum Style {
            case info
            case error
        }

        let id = UUID()
        let text: String
        let style: Style
    }

    private var displayedNotes: [NoteListItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return searchResults.map { result in
                let match = notes.first(where: { $0.id == result.noteId })
                return NoteListItem(
                    id: result.noteId,
                    title: result.matchedTitle,
                    isSecure: result.isSecure,
                    subjectId: match?.subjectId,
                    updatedAt: match?.updatedAt
                )
            }
        }

        return notes.map { summary in
            NoteListItem(
                id: summary.id,
                title: summary.title,
                isSecure: summary.isSecure,
                subjectId: summary.subjectId,
                updatedAt: summary.updatedAt
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

    private var fontSizeLabel: String {
        "Text: \(Int(editorFontSize))"
    }

    var body: some View {
        GeometryReader { geo in
        HStack(alignment: .top, spacing: 0) {
            if !isLeftPanelCollapsed {
                VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .help("Settings")

                    Button {
                        Task {
                            await loadTrashItems()
                            isShowingTrash = true
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .help("Trash Can")

                    Spacer()

                    Button("New Note") {
                        beginNewDraft()
                    }
                }

                HStack {
                    TextField("Search note titles", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: query) { _, _ in
                            userInteractionAction()
                        }
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
                                        .padding(.trailing, 12)
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
                                    toggleGroupCollapse(group)
                                }

                                if !isGroupCollapsed(group) {
                                    ForEach(notesForGroup(group.subjectId)) { note in
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                if note.isSecure {
                                                    Image(systemName: "lock.fill")
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text(note.title)
                                                Spacer(minLength: 0)
                                            }
                                            if let updatedAt = note.updatedAt {
                                                Text(updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
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
                        .onChange(of: newSubjectName) { _, _ in
                            userInteractionAction()
                        }
                    Button("Add") {
                        Task {
                            do {
                                _ = try await createSubjectAction(newSubjectName)
                                newSubjectName = ""
                                await refreshWorkspace()
                            } catch {
                                showToast(mapError(error), style: .error)
                            }
                        }
                    }
                }

                Divider()
            }
            .padding()
            .frame(width: max(200, min(leftPanelWidth, geo.size.width * 0.65)))
            }

            // Draggable divider
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 8)
                .contentShape(Rectangle())
                .onHover { inside in inside ? NSCursor.resizeLeftRight.push() : NSCursor.pop() }
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            if dragStartWidth == nil { dragStartWidth = leftPanelWidth }
                            leftPanelWidth = max(200, min(dragStartWidth! + value.translation.width, geo.size.width * 0.65))
                        }
                        .onEnded { _ in
                            dragStartWidth = nil
                        }
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        isLeftPanelCollapsed.toggle()
                    } label: {
                        Image(systemName: isLeftPanelCollapsed ? "sidebar.right" : "sidebar.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .help(isLeftPanelCollapsed ? "Show left panel" : "Hide left panel")

                    Spacer()
                }

                if selectedNoteId == nil && !isComposingNewNote {
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome to AstraNotes")
                            .font(.largeTitle)
                            .bold()
                        Text("Start by creating a new note, or select one from the left panel to continue editing.")
                            .foregroundStyle(.secondary)
                        Button("Create a Note") {
                            beginNewDraft()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    Spacer()
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(selectedNoteId == nil ? "Create Note" : "Edit Note")
                            .font(.title2)
                            .bold()
                        Spacer()
                        if let updatedAt = loadedUpdatedAt {
                            Text("Last edited \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Title", text: $title)
                        .font(.system(size: 16))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: title) { _, _ in
                            userInteractionAction()
                        }

                    Picker("Subject", selection: $editorSubjectId) {
                        Text("Ungrouped").tag(Optional<UUID>.none)
                        ForEach(subjects, id: \.id) { subject in
                            Text(subject.name).tag(Optional(subject.id))
                        }
                    }

                    Toggle("Secure mode", isOn: $secureModeEnabled)
                        .onChange(of: secureModeEnabled) { _, _ in
                            userInteractionAction()
                        }

                    if secureModeEnabled {
                        TextField("Secure title alias (default: Locked Note)", text: $secureTitleAlias)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: secureTitleAlias) { _, _ in
                                userInteractionAction()
                            }
                    }

                    HStack(spacing: 10) {
                        Stepper(fontSizeLabel, value: $editorFontSize, in: 12...36)
                            .frame(width: 120)
                        colorPresetButton(key: "black", color: .black)
                        colorPresetButton(key: "blue", color: .blue)
                        colorPresetButton(key: "green", color: .green)
                        colorPresetButton(key: "red", color: .red)

                        Button {
                            editorIsBold.toggle()
                            editorApplyStyleRevision += 1
                        } label: {
                            Text("B").bold()
                        }
                        .buttonStyle(.bordered)
                        .tint(editorIsBold ? .accentColor : .secondary)

                        Button {
                            editorIsItalic.toggle()
                            editorApplyStyleRevision += 1
                        } label: {
                            Text("I").italic()
                        }
                        .buttonStyle(.bordered)
                        .tint(editorIsItalic ? .accentColor : .secondary)

                        Button {
                            editorIsUnderlined.toggle()
                            editorApplyStyleRevision += 1
                        } label: {
                            Text("U").underline()
                        }
                        .buttonStyle(.bordered)
                        .tint(editorIsUnderlined ? .accentColor : .secondary)

                        Spacer()
                    }
                    .onChange(of: editorFontSize) { _, _ in
                        userInteractionAction()
                        editorApplyStyleRevision += 1
                    }
                    .onChange(of: editorTextColor) { _, _ in
                        userInteractionAction()
                    }
                    .onChange(of: editorIsBold) { _, _ in
                        userInteractionAction()
                    }
                    .onChange(of: editorIsItalic) { _, _ in
                        userInteractionAction()
                    }
                    .onChange(of: editorIsUnderlined) { _, _ in
                        userInteractionAction()
                    }

                    ZStack {
                        RichTextEditor(
                            text: $content,
                            fontSize: $editorFontSize,
                            textColor: $editorTextColor,
                            textColorKey: $editorTextColorKey,
                            isBold: $editorIsBold,
                            isItalic: $editorIsItalic,
                            isUnderlined: $editorIsUnderlined,
                            applyStyleRevision: $editorApplyStyleRevision
                        ) { selectionStyle in
                            editorFontSize = min(max(selectionStyle.fontSize, 12), 36)
                            editorTextColorKey = selectionStyle.colorKey
                            editorTextColor = colorForKey(selectionStyle.colorKey)
                            editorIsBold = selectionStyle.isBold
                            editorIsItalic = selectionStyle.isItalic
                            editorIsUnderlined = selectionStyle.isUnderlined
                        }
                        .onChange(of: content) { _, _ in
                            userInteractionAction()
                        }
                    }
                    .frame(minHeight: 240)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.4))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Attachments")
                                .font(.headline)

                            Spacer()

                            Button("Add Image") {
                                Task {
                                    await attachImage()
                                }
                            }
                            .disabled(recordingController.isRecording)

                            Button(recordingController.isRecording ? "Stop Recording" : "Record Voice") {
                                Task {
                                    await toggleVoiceRecording()
                                }
                            }
                        }

                        if attachments.isEmpty {
                            Text("No attachments yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(attachments, id: \.id) { attachment in
                                HStack(spacing: 10) {
                                    Image(systemName: attachment.type == .image ? "photo" : "waveform")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachmentName(for: attachment))
                                        Text("\(attachment.type == .image ? "Image" : "Recording") • \(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Open") {
                                        WorkspaceAttachmentImport.open(at: attachment.storagePath)
                                    }
                                    Button("Reveal") {
                                        WorkspaceAttachmentImport.reveal(at: attachment.storagePath)
                                    }
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await deleteAttachment(attachment)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.top, 4)

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
                            beginNewDraft()
                        }
                    }

                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .task(id: geo.size.width) {
            if leftPanelWidth == 0 {
                leftPanelWidth = geo.size.width / 3
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                loadSettingsAction: loadSettingsAction,
                saveSettingsAction: saveSettingsAction,
                updateBiometricAction: updateBiometricAction,
                installedPluginsAction: installedPluginsAction,
                setPluginEnabledAction: setPluginEnabledAction,
                installPluginAction: installPluginAction,
                removePluginAction: removePluginAction,
                changePassphraseAction: changePassphraseAction,
                exportArchiveAction: exportArchiveAction,
                importArchiveAction: importArchiveAction
            )
        }
        .sheet(isPresented: $isShowingTrash) {
            NavigationStack {
                List(trashItems, id: \.trashId) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if item.isSecure {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.isSecure ? (item.secureTitleAlias ?? "Locked Note") : (item.displayTitle ?? "Untitled"))
                                .font(.headline)
                        }
                        Text("Deleted: \(item.deletionTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            if item.isSecure {
                                Button("Why Locked?") {
                                    Task {
                                        do {
                                            let previewMessage = try await secureTrashPreviewAction(item.trashId)
                                            if let previewMessage {
                                                showToast(previewMessage, style: .info)
                                            }
                                        } catch {
                                            showToast(mapError(error), style: .error)
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
                                        showToast(mapError(error), style: .error)
                                    }
                                }
                            }

                            Button("Delete Permanently") {
                                Task {
                                    do {
                                        _ = try await permanentlyDeleteTrashAction(item.trashId)
                                        await loadTrashItems()
                                    } catch {
                                        showToast(mapError(error), style: .error)
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
                Text(secureAccessPromptTitle)
                    .font(.title2)
                    .bold()

                Text(secureAccessPromptMessage)
                    .foregroundStyle(.secondary)

                SecureField("Passphrase", text: $secureAccessPassphrase)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    .onChange(of: secureAccessPassphrase) { _, _ in
                        userInteractionAction()
                    }

                HStack {
                    Button("Cancel", role: .cancel) {
                        pendingSecureAccessAction = nil
                        secureAccessPassphrase = ""
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
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(toasts) { toast in
                    HStack(spacing: 8) {
                        Image(systemName: toast.style == .error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(toast.style == .error ? .red : .green)
                        Text(toast.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 4)
                }
            }
            .padding(.top, 10)
            .padding(.trailing, 12)
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
        } // GeometryReader
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

    private func loadAttachments(for noteId: UUID?) async {
        guard let noteId else {
            attachments = []
            return
        }
        attachments = await listAttachmentsAction(noteId)
    }

    private var secureAccessPromptTitle: String {
        switch pendingSecureAccessAction {
        case .saveSecureDraft:
            return "Authenticate to Save Secure Note"
        case .continueAttachment(let action):
            switch action {
            case .importImage:
                return "Authenticate to Attach Image"
            case .finalizeRecording:
                return "Authenticate to Save Recording"
            }
        case .openSecureNote, .none:
            return "Unlock Secure Note"
        }
    }

    private var secureAccessPromptMessage: String {
        switch pendingSecureAccessAction {
        case .saveSecureDraft:
            return "Enter your passphrase or use biometrics to encrypt and save this secure note."
        case .continueAttachment(let action):
            switch action {
            case .importImage:
                return "Enter your passphrase or use biometrics to save this image attachment to the secure note."
            case .finalizeRecording:
                return "Enter your passphrase or use biometrics to save this recording attachment to the secure note."
            }
        case .openSecureNote, .none:
            return "Enter your passphrase or use biometrics to open this secure note."
        }
    }

    private func requestOpenNote(_ note: NoteListItem) async {
        userInteractionAction()
        if note.isSecure {
            pendingSecureAccessAction = .openSecureNote(note.id)
            secureAccessPassphrase = ""
            isShowingSecureAccessPrompt = true
            return
        }

        await selectNote(note.id)
    }

    private func selectNote(_ noteId: UUID) async {
        do {
            let loaded = try await loadNoteAction(noteId)
            isComposingNewNote = false
            selectedNoteId = loaded.id
            selectedSubjectId = loaded.subjectId
            collapsedGroupIDs.remove(groupID(for: loaded.subjectId))
            title = loaded.title
            content = loaded.content
            loadedTitleSnapshot = loaded.title
            loadedContentSnapshot = loaded.content
            loadedSubjectIdSnapshot = loaded.subjectId
            loadedSecureModeSnapshot = loaded.isSecure
            secureModeEnabled = loaded.isSecure
            secureTitleAlias = loaded.secureTitleAlias ?? ""
            loadedSecureAliasSnapshot = loaded.secureTitleAlias ?? ""
            editorSubjectId = loaded.subjectId
            loadedUpdatedAt = loaded.updatedAt
            await loadAttachments(for: loaded.id)
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func authenticatePendingSecureNoteWithPassphrase() async {
        guard let pendingSecureAccessAction else {
            return
        }

        do {
            try await secureNotePassphraseAuthAction(secureAccessPassphrase)
            switch pendingSecureAccessAction {
            case .openSecureNote(let noteId):
                await selectNote(noteId)
            case .saveSecureDraft:
                await saveCurrentDraft(retryingAfterReauth: true)
            case .continueAttachment(let action):
                await completePendingAttachment(action, retryingAfterReauth: true)
            }
            secureAccessPassphrase = ""
            self.pendingSecureAccessAction = nil
            isShowingSecureAccessPrompt = false
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func authenticatePendingSecureNoteWithBiometrics(action: () async throws -> Void) async {
        guard let pendingSecureAccessAction else {
            return
        }

        do {
            try await action()
            switch pendingSecureAccessAction {
            case .openSecureNote(let noteId):
                await selectNote(noteId)
            case .saveSecureDraft:
                await saveCurrentDraft(retryingAfterReauth: true)
            case .continueAttachment(let pendingAction):
                await completePendingAttachment(pendingAction, retryingAfterReauth: true)
            }
            secureAccessPassphrase = ""
            self.pendingSecureAccessAction = nil
            isShowingSecureAccessPrompt = false
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func saveCurrentDraft(retryingAfterReauth: Bool = false) async {
        userInteractionAction()
        if let selectedNoteId,
           loadedSecureModeSnapshot,
           secureModeEnabled,
           title == loadedTitleSnapshot,
           content == loadedContentSnapshot {
            let secureAliasChanged = secureTitleAlias != loadedSecureAliasSnapshot
            let secureSubjectChanged = editorSubjectId != loadedSubjectIdSnapshot

            if secureAliasChanged || secureSubjectChanged {
                do {
                    try await updateSecureMetadataAction(selectedNoteId, secureTitleAlias, editorSubjectId)
                    showToast("Secure note metadata saved.", style: .info)
                    await refreshWorkspace()
                    await selectNote(selectedNoteId)
                } catch {
                    showToast(mapError(error), style: .error)
                }
                return
            }
        }

        do {
            let draft = NoteDraft(
                id: selectedNoteId,
                title: title,
                content: content,
                subjectId: editorSubjectId,
                secureModeEnabled: secureModeEnabled,
                secureTitleAlias: secureModeEnabled ? secureTitleAlias : nil,
                expirationUTC: nil
            )

            let savedId = try await saveDraftAction(draft)
            selectedNoteId = savedId
            showToast("Note saved.", style: .info)
            await refreshWorkspace()
            await selectNote(savedId)
        } catch NoteServiceError.keyMaterialUnavailable where secureModeEnabled {
            // Existing note: if only alias/subject changed, save without requiring key material.
            if let selectedNoteId,
               loadedSecureModeSnapshot,
               (secureTitleAlias != loadedSecureAliasSnapshot || editorSubjectId != loadedSubjectIdSnapshot),
               title == loadedTitleSnapshot,
               content == loadedContentSnapshot {
                do {
                    try await updateSecureMetadataAction(selectedNoteId, secureTitleAlias, editorSubjectId)
                    showToast("Secure note alias saved.", style: .info)
                    await refreshWorkspace()
                    await selectNote(selectedNoteId)
                    return
                } catch {
                    showToast(mapError(error), style: .error)
                    return
                }
            }

            // New note or content change: encryption is genuinely required — prompt auth.
            if !retryingAfterReauth {
                pendingSecureAccessAction = .saveSecureDraft
                secureAccessPassphrase = ""
                isShowingSecureAccessPrompt = true
            } else {
                showToast("Authentication failed. Secure note not saved.", style: .error)
            }
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func deleteSelectedNote() async {
        guard let selectedNoteId else {
            return
        }

        let deletedNoteTitle = title
        let deletedNoteWasSecure = secureModeEnabled
        let deletedNoteAlias = secureTitleAlias

        do {
            _ = try await deleteNoteAction(selectedNoteId)
            appendOptimisticTrashItem(
                sourceNoteId: selectedNoteId,
                isSecure: deletedNoteWasSecure,
                displayTitle: deletedNoteWasSecure ? nil : deletedNoteTitle,
                secureTitleAlias: deletedNoteWasSecure ? (deletedNoteAlias.isEmpty ? "Locked Note" : deletedNoteAlias) : nil
            )
            clearEditorForNewNote()
            showToast("Note moved to protected trash.", style: .info)
            await loadTrashItems()
            Task {
                await refreshWorkspace()
            }
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func appendOptimisticTrashItem(
        sourceNoteId: UUID,
        isSecure: Bool,
        displayTitle: String?,
        secureTitleAlias: String? = nil
    ) {
        let candidate = TrashItemView(
            trashId: UUID(),
            sourceNoteId: sourceNoteId,
            isSecure: isSecure,
            displayTitle: displayTitle,
            secureTitleAlias: secureTitleAlias,
            deletionTime: Date(),
            lockBadgeVisible: isSecure
        )

        guard !trashItems.contains(where: { $0.sourceNoteId == sourceNoteId }) else {
            return
        }

        trashItems.insert(candidate, at: 0)
    }

    private func deleteSubject(_ subject: Subject) async {
        do {
            _ = try await deleteSubjectAction(subject.id)
            if selectedSubjectId == subject.id {
                selectedSubjectId = nil
            }
            showToast("Subject deleted; notes are now ungrouped.", style: .info)
            await refreshWorkspace()
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func clearEditorForNewNote() {
        selectedNoteId = nil
        isComposingNewNote = false
        title = ""
        content = ""
        loadedTitleSnapshot = ""
        loadedContentSnapshot = ""
        loadedSubjectIdSnapshot = nil
        loadedSecureModeSnapshot = false
        secureModeEnabled = false
        secureTitleAlias = ""
        loadedSecureAliasSnapshot = ""
        editorFontSize = 16
        editorTextColor = .black
        editorTextColorKey = "black"
        editorApplyStyleRevision = 0
        editorIsBold = false
        editorIsItalic = false
        editorIsUnderlined = false
        editorSubjectId = selectedSubjectId
        loadedUpdatedAt = nil
        attachments = []
        recordingController.cancel()
    }

    private func beginNewDraft() {
        selectedNoteId = nil
        isComposingNewNote = true
        title = ""
        content = ""
        loadedTitleSnapshot = ""
        loadedContentSnapshot = ""
        loadedSubjectIdSnapshot = nil
        loadedSecureModeSnapshot = false
        secureModeEnabled = false
        secureTitleAlias = ""
        loadedSecureAliasSnapshot = ""
        editorFontSize = 16
        editorTextColor = .black
        editorTextColorKey = "black"
        editorApplyStyleRevision = 0
        editorIsBold = false
        editorIsItalic = false
        editorIsUnderlined = false
        editorSubjectId = selectedSubjectId
        loadedUpdatedAt = nil
        attachments = []
        recordingController.cancel()
    }

    @ViewBuilder
    private func colorPresetButton(key: String, color: Color) -> some View {
        Button {
            editorTextColorKey = key
            editorTextColor = color
            editorApplyStyleRevision += 1
        } label: {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .padding(4)
                .overlay(
                    Circle()
                        .stroke(editorTextColorKey == key ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func colorForKey(_ key: String) -> Color {
        switch key {
        case "red":
            return .red
        case "green":
            return .green
        case "blue":
            return .blue
        default:
            return .black
        }
    }

    private func attachmentName(for attachment: Attachment) -> String {
        URL(fileURLWithPath: attachment.storagePath).lastPathComponent
    }

    private func deleteAttachment(_ attachment: Attachment) async {
        userInteractionAction()
        do {
            try await deleteAttachmentAction(attachment.noteId, attachment.id)
            attachments.removeAll { $0.id == attachment.id }
            showToast("Attachment deleted.", style: .info)
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func attachImage() async {
        if recordingController.isRecording {
            showToast("Stop recording before attaching an image.", style: .error)
            return
        }

        guard let sourceURL = WorkspaceAttachmentImport.chooseImageFileURL() else {
            return
        }

        await completePendingAttachment(.importImage(sourceURL), retryingAfterReauth: false)
    }

    private func toggleVoiceRecording() async {
        if recordingController.isRecording {
            do {
                let result = try recordingController.stop()
                await completePendingAttachment(.finalizeRecording(storagePath: result.storagePath, byteSize: result.byteSize), retryingAfterReauth: false)
            } catch {
                showToast(mapError(error), style: .error)
            }
            return
        }

        do {
            try await recordingController.start()
            showToast("Recording started.", style: .info)
        } catch {
            showToast(mapError(error), style: .error)
        }
    }

    private func completePendingAttachment(_ action: PendingAttachmentAction, retryingAfterReauth: Bool) async {
        do {
            let noteId = try await ensureNoteReadyForAttachment(retryingAfterReauth: retryingAfterReauth, pendingAction: action)

            switch action {
            case .importImage(let sourceURL):
                let imported = try WorkspaceAttachmentImport.importImage(from: sourceURL)
                do {
                    _ = try await addImageAttachmentAction(noteId, imported.storagePath, imported.byteSize)
                } catch {
                    try? FileManager.default.removeItem(atPath: imported.storagePath)
                    throw error
                }
                showToast("Image attached.", style: .info)
            case .finalizeRecording(let storagePath, let byteSize):
                _ = try await addVoiceAttachmentAction(noteId, storagePath, byteSize)
                showToast("Recording attached.", style: .info)
            }

            await loadAttachments(for: noteId)
            await refreshWorkspace()
            if selectedNoteId != noteId {
                await selectNote(noteId)
            }
        } catch NoteServiceError.keyMaterialUnavailable where !retryingAfterReauth {
            pendingSecureAccessAction = .continueAttachment(action)
            secureAccessPassphrase = ""
            isShowingSecureAccessPrompt = true
        } catch {
            cleanupPendingAttachment(action)
            showToast(mapError(error), style: .error)
        }
    }

    private func ensureNoteReadyForAttachment(retryingAfterReauth: Bool, pendingAction: PendingAttachmentAction) async throws -> UUID {
        if let selectedNoteId {
            return selectedNoteId
        }

        let draft = NoteDraft(
            id: selectedNoteId,
            title: title,
            content: content,
            subjectId: editorSubjectId,
            secureModeEnabled: secureModeEnabled,
            secureTitleAlias: secureModeEnabled ? secureTitleAlias : nil,
            expirationUTC: nil
        )

        do {
            let savedId = try await saveDraftAction(draft)
            selectedNoteId = savedId
            await refreshWorkspace()
            await selectNote(savedId)
            return savedId
        } catch NoteServiceError.keyMaterialUnavailable where secureModeEnabled && !retryingAfterReauth {
            pendingSecureAccessAction = .continueAttachment(pendingAction)
            secureAccessPassphrase = ""
            isShowingSecureAccessPrompt = true
            throw NoteServiceError.keyMaterialUnavailable
        }
    }

    private func cleanupPendingAttachment(_ action: PendingAttachmentAction) {
        switch action {
        case .importImage:
            return
        case .finalizeRecording(let storagePath, _):
            try? FileManager.default.removeItem(atPath: storagePath)
        }
    }

    private func showToast(_ text: String, style: ToastMessage.Style) {
        let toast = ToastMessage(text: text, style: style)
        withAnimation {
            toasts.append(toast)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                toasts.removeAll { $0.id == toast.id }
            }
        }
    }

    private func mapError(_ error: Error) -> String {
        switch error {
        case NoteServiceError.titleRequired:
            return "Title is required."
        case NoteServiceError.keyMaterialUnavailable:
            return "Secure note key is locked. Authenticate to save secure notes."
        case NoteServiceError.imageAttachmentTooLarge:
            return "Image attachment exceeds the 20 MB size limit."
        case NoteServiceError.voiceAttachmentTooLarge:
            return "Voice attachment exceeds the 50 MB size limit."
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
        case RecordingError.microphonePermissionDenied:
            return "Microphone access is required to record audio attachments."
        case RecordingError.startFailed:
            return "Audio recording could not be started."
        case RecordingError.notRecording:
            return "No active recording was found."
        default:
            return String(describing: error)
        }
    }
}

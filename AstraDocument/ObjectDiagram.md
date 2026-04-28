# AstraNotes Object Diagram

```mermaid
flowchart LR

    %% Runtime objects (instances)
    notesWorkspaceView[notesWorkspaceView]
    trashView[trashView]

    appCoordinator[appCoordinator\nstate=unlocked]
    keyManager[keyManager\nkeyLoaded=true]
    localAuthService[localAuthService]

    noteService[noteService]
    encryptionService[encryptionService]
    secureNotePolicyService[secureNotePolicyService]
    protectedTrashService[protectedTrashService]
    noteSearchService[noteSearchService\nsecureTitleCache=loaded]
    pluginService[pluginService]
    exportImportService[exportImportService]

    noteRepository[noteRepository]
    protectedTrashRepository[protectedTrashRepository]
    databaseProvider[databaseProvider]
    notificationService[notificationService]

    noteObject[noteObject\nid=101\nisSecure=true\ntitle="Project Plan"\nexpiresAt=2026-05-10 09:00]
    attachmentObject[attachmentObject\nid=501\nnoteId=101]

    %% Instance links
    noteObject -->|has| attachmentObject

    appCoordinator -->|manages session| keyManager
    appCoordinator -->|biometric auth| localAuthService

    keyManager -->|provides key| encryptionService
    keyManager -->|clears on lock| noteSearchService

    notesWorkspaceView -->|create edit delete| noteService
    notesWorkspaceView -->|search title| noteSearchService
    trashView -->|restore delete| protectedTrashService

    noteService -->|save and fetch| noteRepository
    noteService -->|encrypt and decrypt secure content| encryptionService
    noteService -->|validate expiration| secureNotePolicyService

    secureNotePolicyService -->|move expired secure note| protectedTrashService
    secureNotePolicyService -->|schedule reminder| notificationService

    noteSearchService -->|query normal titles| noteRepository
    noteSearchService -->|decrypt secure titles in memory| encryptionService

    pluginService -->|apply text transform result| noteService
    exportImportService -->|backup and restore notes| noteRepository
    exportImportService -->|archive crypto| encryptionService

    protectedTrashService -->|store trash records| protectedTrashRepository
    noteRepository -->|transaction| databaseProvider
    protectedTrashRepository -->|transaction| databaseProvider

    noteRepository -->|loads| noteObject
```
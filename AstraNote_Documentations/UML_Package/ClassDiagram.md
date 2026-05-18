# AstraNotes Class Diagram (Refined, HTML)

The diagram below is generated with HTML + inline SVG so it can be previewed without Mermaid.

<div style="overflow-x:auto; border:1px solid #d9d9d9; border-radius:10px; background:#fcfcfc;">
  <svg viewBox="0 0 1950 1680" width="1950" height="1680" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="AstraNotes class diagram">
    <defs>
      <style>
        .title { font: 700 18px Arial, sans-serif; fill: #1f2937; }
        .cardTitle { font: 700 14px Arial, sans-serif; fill: #0f172a; }
        .st { font: 12px Arial, sans-serif; fill: #1f2937; }
        .small { font: 11px Arial, sans-serif; fill: #374151; }
        .ui { fill: #e7f1ff; stroke: #5b8def; }
        .core { fill: #e9fbe9; stroke: #39a96b; }
        .data { fill: #fff7df; stroke: #e3a008; }
        .platform { fill: #ffeaea; stroke: #dc6a6a; }
        .model { fill: #f3edff; stroke: #8b6adf; }
        .edge { stroke: #4b5563; stroke-width: 1.4; fill: none; marker-end: url(#arrow); }
      </style>
      <marker id="arrow" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
        <path d="M 0 0 L 10 5 L 0 10 z" fill="#4b5563" />
      </marker>
    </defs>

    <text x="20" y="28" class="title">AstraNotes layered class view (derived from Architecture + Requirements)</text>

    <text x="30" y="60" class="cardTitle">AstraUI</text>
    <text x="400" y="60" class="cardTitle">AstraCore</text>
    <text x="840" y="60" class="cardTitle">AstraData</text>
    <text x="1260" y="60" class="cardTitle">AstraPlatform</text>
    <text x="1570" y="60" class="cardTitle">Core Models</text>

    <rect x="30" y="80" width="290" height="120" rx="8" class="ui" />
    <text x="44" y="102" class="cardTitle">UnlockView</text>
    <text x="44" y="124" class="small">+submitPassphrase()</text>
    <text x="44" y="142" class="small">+requestBiometric()</text>

    <rect x="30" y="230" width="290" height="136" rx="8" class="ui" />
    <text x="44" y="252" class="cardTitle">NotesWorkspaceView</text>
    <text x="44" y="274" class="small">+searchByTitle(query)</text>
    <text x="44" y="292" class="small">+createOrUpdateNote()</text>
    <text x="44" y="310" class="small">+assignSubject(noteId, subjectId)</text>

    <rect x="30" y="396" width="290" height="120" rx="8" class="ui" />
    <text x="44" y="418" class="cardTitle">TrashView</text>
    <text x="44" y="440" class="small">+restore(itemId)</text>
    <text x="44" y="458" class="small">+permanentDelete(itemId)</text>

    <rect x="30" y="546" width="290" height="120" rx="8" class="ui" />
    <text x="44" y="568" class="cardTitle">SettingsView</text>
    <text x="44" y="590" class="small">+changeTimeout()</text>
    <text x="44" y="608" class="small">+changePassphrase()</text>

    <rect x="30" y="696" width="290" height="120" rx="8" class="ui" />
    <text x="44" y="718" class="cardTitle">PluginStoreView</text>
    <text x="44" y="740" class="small">+installLocalPackage()</text>
    <text x="44" y="758" class="small">+togglePlugin(pluginId)</text>

    <rect x="400" y="80" width="330" height="120" rx="8" class="core" />
    <text x="414" y="102" class="cardTitle">AppCoordinator</text>
    <text x="414" y="124" class="small">+routeOnLaunch()</text>
    <text x="414" y="142" class="small">+lock()</text>

    <rect x="400" y="220" width="330" height="132" rx="8" class="core" />
    <text x="414" y="242" class="cardTitle">KeyManager</text>
    <text x="414" y="264" class="small">+unlockWithPassphrase()</text>
    <text x="414" y="282" class="small">+unlockWithBiometric()</text>
    <text x="414" y="300" class="small">+clearKeys()</text>

    <rect x="400" y="372" width="330" height="148" rx="8" class="core" />
    <text x="414" y="394" class="cardTitle">NoteService</text>
    <text x="414" y="416" class="small">+saveNote(noteDraft)</text>
    <text x="414" y="434" class="small">+deleteNote(noteId)</text>
    <text x="414" y="452" class="small">+persistSecureDraftOnLock()</text>
    <text x="414" y="470" class="small">+moveBetweenSubjects()</text>

    <rect x="400" y="540" width="330" height="120" rx="8" class="core" />
    <text x="414" y="562" class="cardTitle">SecureNotePolicyService</text>
    <text x="414" y="584" class="small">+validateExpiration()</text>
    <text x="414" y="602" class="small">+scanAndExpireSecureNotes()</text>

    <rect x="400" y="680" width="330" height="120" rx="8" class="core" />
    <text x="414" y="702" class="cardTitle">ProtectedTrashService</text>
    <text x="414" y="724" class="small">+moveToTrash(noteId)</text>
    <text x="414" y="742" class="small">+restore(itemId)</text>

    <rect x="400" y="820" width="330" height="120" rx="8" class="core" />
    <text x="414" y="842" class="cardTitle">NoteSearchService</text>
    <text x="414" y="864" class="small">+searchTitles(query)</text>
    <text x="414" y="882" class="small">+clearSecureTitleCacheOnLock()</text>

    <rect x="400" y="960" width="330" height="120" rx="8" class="core" />
    <text x="414" y="982" class="cardTitle">SubjectService</text>
    <text x="414" y="1004" class="small">+createSubject(name)</text>
    <text x="414" y="1022" class="small">+renameOrDeleteSubject()</text>

    <rect x="400" y="1100" width="330" height="120" rx="8" class="core" />
    <text x="414" y="1122" class="cardTitle">SettingsService</text>
    <text x="414" y="1144" class="small">+validateAndSaveSettings()</text>
    <text x="414" y="1162" class="small">+changePassphraseWithRotation()</text>

    <rect x="400" y="1240" width="330" height="120" rx="8" class="core" />
    <text x="414" y="1262" class="cardTitle">PluginService</text>
    <text x="414" y="1284" class="small">+validateManifest()</text>
    <text x="414" y="1302" class="small">+executeActionWithTimeout()</text>

    <rect x="400" y="1380" width="330" height="120" rx="8" class="core" />
    <text x="414" y="1402" class="cardTitle">ExportImportService</text>
    <text x="414" y="1424" class="small">+exportEncryptedArchive()</text>
    <text x="414" y="1442" class="small">+importAtomicWithConflictResolution()</text>

    <rect x="400" y="1520" width="330" height="120" rx="8" class="core" />
    <text x="414" y="1542" class="cardTitle">EncryptionService</text>
    <text x="414" y="1564" class="small">+encrypt(plain, key)</text>
    <text x="414" y="1582" class="small">+decrypt(payload, key)</text>

    <rect x="840" y="80" width="320" height="104" rx="8" class="data" />
    <text x="854" y="102" class="cardTitle">DatabaseProvider</text>
    <text x="854" y="124" class="small">+transaction()</text>
    <text x="854" y="142" class="small">+migrate()</text>

    <rect x="840" y="210" width="320" height="104" rx="8" class="data" />
    <text x="854" y="232" class="cardTitle">NoteRepository</text>
    <text x="854" y="254" class="small">+save(Note)</text>
    <text x="854" y="272" class="small">+findByTitle()</text>

    <rect x="840" y="340" width="320" height="104" rx="8" class="data" />
    <text x="854" y="362" class="cardTitle">AttachmentRepository</text>
    <text x="854" y="384" class="small">+save(Attachment)</text>
    <text x="854" y="402" class="small">+deleteByNoteId()</text>

    <rect x="840" y="470" width="320" height="104" rx="8" class="data" />
    <text x="854" y="492" class="cardTitle">SubjectRepository</text>
    <text x="854" y="514" class="small">+save(SubjectGroup)</text>
    <text x="854" y="532" class="small">+setSubjectNullOnDelete()</text>

    <rect x="840" y="600" width="320" height="104" rx="8" class="data" />
    <text x="854" y="622" class="cardTitle">ProtectedTrashRepository</text>
    <text x="854" y="644" class="small">+save(TrashItem)</text>
    <text x="854" y="662" class="small">+restore(itemId)</text>

    <rect x="840" y="730" width="320" height="104" rx="8" class="data" />
    <text x="854" y="752" class="cardTitle">SettingsRepository</text>
    <text x="854" y="774" class="small">+save(AppSettings)</text>
    <text x="854" y="792" class="small">+load()</text>

    <rect x="840" y="860" width="320" height="104" rx="8" class="data" />
    <text x="854" y="882" class="cardTitle">PluginMetadataRepository</text>
    <text x="854" y="904" class="small">+save(PluginMetadata)</text>
    <text x="854" y="922" class="small">+updateLastRunStatus()</text>

    <rect x="1260" y="80" width="270" height="104" rx="8" class="platform" />
    <text x="1274" y="102" class="cardTitle">LocalAuthService</text>
    <text x="1274" y="124" class="small">+authenticateBiometric()</text>
    <text x="1274" y="142" class="small">+availability()</text>

    <rect x="1260" y="210" width="270" height="104" rx="8" class="platform" />
    <text x="1274" y="232" class="cardTitle">NotificationService</text>
    <text x="1274" y="254" class="small">+notifyExpiry()</text>
    <text x="1274" y="272" class="small">+scheduleLocalNotification()</text>

    <rect x="1260" y="340" width="270" height="104" rx="8" class="platform" />
    <text x="1274" y="362" class="cardTitle">TimeProvider</text>
    <text x="1274" y="384" class="small">+utcNow()</text>
    <text x="1274" y="402" class="small">+isClockRollbackDetected()</text>

    <rect x="1260" y="470" width="270" height="104" rx="8" class="platform" />
    <text x="1274" y="492" class="cardTitle">PlatformIntegration</text>
    <text x="1274" y="514" class="small">+onBackground()</text>
    <text x="1274" y="532" class="small">+onSleep()</text>

    <rect x="1260" y="600" width="270" height="104" rx="8" class="platform" />
    <text x="1274" y="622" class="cardTitle">Logging</text>
    <text x="1274" y="644" class="small">+audit(event)</text>
    <text x="1274" y="662" class="small">+error(message)</text>

    <rect x="1570" y="80" width="340" height="118" rx="8" class="model" />
    <text x="1584" y="102" class="cardTitle">Note</text>
    <text x="1584" y="124" class="small">+id: UUID</text>
    <text x="1584" y="142" class="small">+subjectId: UUID?  +isSecure: Bool</text>
    <text x="1584" y="160" class="small">+expiresAtUtc: Date?  +timestamps</text>

    <rect x="1570" y="220" width="340" height="104" rx="8" class="model" />
    <text x="1584" y="242" class="cardTitle">EncryptedPayload</text>
    <text x="1584" y="264" class="small">+ciphertext: Data</text>
    <text x="1584" y="282" class="small">+nonce: Data  +salt: Data</text>

    <rect x="1570" y="350" width="340" height="104" rx="8" class="model" />
    <text x="1584" y="372" class="cardTitle">Attachment</text>
    <text x="1584" y="394" class="small">+id: UUID  +noteId: UUID</text>
    <text x="1584" y="412" class="small">+type: image | recording  +path</text>

    <rect x="1570" y="480" width="340" height="104" rx="8" class="model" />
    <text x="1584" y="502" class="cardTitle">SubjectGroup</text>
    <text x="1584" y="524" class="small">+id: UUID  +name: String</text>
    <text x="1584" y="542" class="small">+displayOrder: Int</text>

    <rect x="1570" y="610" width="340" height="104" rx="8" class="model" />
    <text x="1584" y="632" class="cardTitle">TrashItem</text>
    <text x="1584" y="654" class="small">+sourceNoteId: UUID  +isSecure: Bool</text>
    <text x="1584" y="672" class="small">+deletedAtUtc: Date</text>

    <rect x="1570" y="740" width="340" height="104" rx="8" class="model" />
    <text x="1584" y="762" class="cardTitle">AppSettings</text>
    <text x="1584" y="784" class="small">+lockTimeoutSec: Int</text>
    <text x="1584" y="802" class="small">+telemetryOptIn: Bool  +pluginsEnabled</text>

    <rect x="1570" y="870" width="340" height="104" rx="8" class="model" />
    <text x="1584" y="892" class="cardTitle">PluginManifest</text>
    <text x="1584" y="914" class="small">+pluginId +name +version</text>
    <text x="1584" y="932" class="small">+supportedAppVersion +entryAction</text>

    <rect x="1570" y="1000" width="340" height="120" rx="8" class="model" />
    <text x="1584" y="1022" class="cardTitle">PluginMetadata</text>
    <text x="1584" y="1044" class="small">+pluginId  +enabled</text>
    <text x="1584" y="1062" class="small">+installPathHash  +lastRunStatus</text>
    <text x="1584" y="1080" class="small">+lastError</text>

    <line x1="320" y1="140" x2="400" y2="140" class="edge" />
    <line x1="320" y1="290" x2="400" y2="430" class="edge" />
    <line x1="320" y1="290" x2="400" y2="870" class="edge" />
    <line x1="320" y1="456" x2="400" y2="740" class="edge" />
    <line x1="320" y1="606" x2="400" y2="1160" class="edge" />
    <line x1="320" y1="756" x2="400" y2="1300" class="edge" />

    <line x1="730" y1="140" x2="1260" y2="140" class="edge" />
    <line x1="730" y1="140" x2="1260" y2="520" class="edge" />
    <line x1="730" y1="286" x2="1260" y2="140" class="edge" />
    <line x1="730" y1="432" x2="840" y2="262" class="edge" />
    <line x1="730" y1="452" x2="840" y2="392" class="edge" />
    <line x1="730" y1="470" x2="400" y2="1580" class="edge" />
    <line x1="730" y1="590" x2="400" y2="740" class="edge" />
    <line x1="730" y1="610" x2="1260" y2="260" class="edge" />
    <line x1="730" y1="620" x2="1260" y2="390" class="edge" />
    <line x1="730" y1="742" x2="840" y2="652" class="edge" />
    <line x1="730" y1="870" x2="840" y2="262" class="edge" />
    <line x1="730" y1="1008" x2="840" y2="522" class="edge" />
    <line x1="730" y1="1144" x2="840" y2="782" class="edge" />
    <line x1="730" y1="1284" x2="840" y2="912" class="edge" />
    <line x1="730" y1="1302" x2="400" y2="432" class="edge" />
    <line x1="730" y1="1424" x2="840" y2="262" class="edge" />
    <line x1="730" y1="1442" x2="400" y2="1580" class="edge" />

    <line x1="1160" y1="262" x2="840" y2="132" class="edge" />
    <line x1="1160" y1="392" x2="840" y2="132" class="edge" />
    <line x1="1160" y1="522" x2="840" y2="132" class="edge" />
    <line x1="1160" y1="652" x2="840" y2="132" class="edge" />
    <line x1="1160" y1="782" x2="840" y2="132" class="edge" />
    <line x1="1160" y1="912" x2="840" y2="132" class="edge" />

    <line x1="730" y1="1560" x2="1570" y2="272" class="edge" />
    <line x1="730" y1="432" x2="1570" y2="140" class="edge" />
    <line x1="730" y1="432" x2="1570" y2="402" class="edge" />
    <line x1="730" y1="1008" x2="1570" y2="532" class="edge" />
    <line x1="730" y1="742" x2="1570" y2="662" class="edge" />
    <line x1="730" y1="1144" x2="1570" y2="792" class="edge" />
    <line x1="730" y1="1284" x2="1570" y2="912" class="edge" />
    <line x1="1160" y1="912" x2="1570" y2="1062" class="edge" />

    <text x="20" y="1660" class="st">Legend: blue=UI, green=core services, yellow=data repositories, red=platform wrappers, purple=domain/data models.</text>
  </svg>
</div>

## Relationship Notes

- UI classes invoke core services only (no direct encryption or repository calls).
- Core services orchestrate business rules and delegate persistence to repositories.
- Repositories are transaction-backed through `DatabaseProvider`.
- Secure note encryption/decryption boundaries stay in `EncryptionService`.
- Secure title search is session-memory behavior in `NoteSearchService` and is cleared on lock.
- Plugin execution is isolated in `PluginService` and persists runtime status through `PluginMetadataRepository`.

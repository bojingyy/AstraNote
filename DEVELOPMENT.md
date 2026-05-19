# AstraNotes Development Environment Setup

## Overview
AstraNotes is organized as a **hybrid Xcode project + Swift Package Manager** structure with the following modules:
- **AstraUI**: Main app target (Phase 4)
- **AstraCore**: Business logic and services (Phases 1-5)
- **AstraData**: Data persistence layer (Phases 1-2)
- **AstraPlatform**: Platform integrations (Phases 4-5)

## Prerequisites

### Required
- **macOS 14+** (Sonoma or later)
- **Xcode 15+** (includes Swift 5.9)
- **Git** (for version control)

### Optional but Recommended
- **SwiftLint** (for code style enforcement)
- **SwiftFormat** (for code formatting)
- **Homebrew** (for package management)

## Installation

### 1. Install Xcode (if not already installed)
```bash
# Install Xcode from App Store or:
xcode-select --install
```

### 2. Verify Swift Installation
```bash
swift --version
```

### 3. Install SwiftLint and SwiftFormat (Recommended)
```bash
brew install swiftlint swiftformat
```

### 4. Clone and Navigate to Project
```bash
cd /path/to/AstraNotes
```

## Building the Project

### Build All Targets
```bash
swift build -v
```

### Build Specific Module
```bash
swift build --package-path . -v
```

### Build Release Configuration
```bash
swift build -c release
```

## Running Tests

### Run All Tests
```bash
swift test -v
```

### Run Specific Test Target
```bash
swift test --filter AstraCoreTests -v
swift test --filter AstraDataTests -v
swift test --filter AstraPlatformTests -v
swift test --filter AstraIntegrationTests -v
```

### Run Tests with Coverage
```bash
swift test --enable-code-coverage
```

## Code Quality Tools

### SwiftLint
Check code style issues:
```bash
swiftlint Sources/ Tests/
```

Autocorrect issues:
```bash
swiftlint autocorrect --path Sources/ --path Tests/
```

### SwiftFormat
Format code:
```bash
swiftformat Sources/ Tests/
```

Dry-run (preview changes):
```bash
swiftformat Sources/ Tests/ --dryrun
```

## Project Structure

```
AstraNotes/
├── Sources/
│   ├── AstraUI/               # Main app target (SwiftUI)
│   │   ├── AstraNotesApp.swift
│   │   ├── ContentView.swift
│   │   └── Views/             # (To be created in Phase 4)
│   ├── AstraCore/             # Business logic & services
│   │   ├── AstraCore.swift
│   │   ├── Services/          # (Phases 1-5)
│   │   ├── Models/            # (Phases 1-2)
│   │   └── Policies/          # (Phases 3-5)
│   ├── AstraData/             # Data persistence
│   │   ├── AstraData.swift
│   │   ├── Database/          # (Phase 1)
│   │   └── Repositories/      # (Phases 2-5)
│   └── AstraPlatform/         # Platform integrations
│       ├── AstraPlatform.swift
│       ├── Services/          # LocalAuth, Storage, Logging, etc.
│       └── Models/            # (If needed)
├── Tests/
│   ├── AstraCoreTests/
│   ├── AstraDataTests/
│   ├── AstraPlatformTests/
│   └── AstraIntegrationTests/
├── Package.swift              # Swift Package manifest
├── .swiftlint.yml             # SwiftLint configuration
├── .swiftformat               # SwiftFormat configuration
├── .github/
│   └── workflows/
│       └── build-and-test.yml # CI/CD pipeline
└── AstraNote_Documentations/  # Project documentation
    ├── Requirement.md         # All 96 requirements
    ├── Architecture.md        # System design
    ├── TestSteps.md          # Comprehensive test plan
    ├── ImplementationPlan.md # 5-phase roadmap
    ├── DoneCretaria.md       # Acceptance criteria
    └── ...
```

## Key Features by Phase

### Phase 1 (Weeks 1-3): Foundation
- [ ] Database setup with ACID transactions
- [ ] AES-GCM encryption with test vectors
- [ ] Passphrase hashing (PBKDF2)
- [ ] Rate-limited unlock (5 attempts → 30s lockout, exponential)

### Phase 2 (Weeks 4-5): Core Note Lifecycle
- [ ] Normal note CRUD (plain text)
- [ ] Subject group management
- [ ] Basic repositories with atomic writes

### Phase 3 (Weeks 6-8): Secure Notes
- [ ] Secure mode toggle with expiration controls
- [ ] AES-GCM encryption before storage
- [ ] Protected trash with correct display semantics
- [ ] Time-rollback guard (FR4.5)
- [ ] Expiration checks on launch + periodic

### Phase 4 (Weeks 9-10): Session Management & Media
- [ ] Passphrase and biometric unlock
- [ ] Auto-lock (inactivity, sleep, background)
- [ ] Title search (normal + secure with in-memory cache)
- [ ] Voice capture and image attachments
- [ ] Performance: Unlock ≤1s (1k notes), ≤2s (10k notes)

### Phase 5 (Weeks 11-13): Advanced Features
- [ ] Passphrase change with atomic key rotation
- [ ] Partial migration recovery
- [ ] Export/import with atomic semantics
- [ ] Simple plugin support (text transform)
- [ ] Accessibility (keyboard, VoiceOver)
- [ ] Internationalization (English-first)

## CI/CD Pipeline

GitHub Actions automatically runs on push and pull request:
1. **Build** - Swift build for all targets
2. **Unit Tests** - AstraCore, AstraData, AstraPlatform
3. **Integration Tests** - End-to-end feature flows
4. **Code Coverage** - Upload to Codecov
5. **SwiftLint** - Code style checks with PR comments
6. **Security Scan** - Check for unsafe patterns

View workflow status: `.github/workflows/build-and-test.yml`

## Debugging

### Enable Verbose Output
```bash
swift build -v
swift test -v
```

### Run Single Integration Test
```bash
swift test --filter AstraIntegrationTests.testFirstLaunchInitialization -v
```

### Generate Code Coverage Report
```bash
swift test --enable-code-coverage
open coverage.xml  # View in Xcode or browser
```

## Code Style Guidelines

- **Indentation**: 4 spaces
- **Line length**: Warn at 120, error at 200 characters
- **Force operations**: Avoid `!`, use `guard` or `if let`
- **Complexity**: Keep cyclomatic complexity < 15
- **Comments**: Document public APIs and complex logic
- **Naming**: Clear, descriptive names for all symbols

See `.swiftlint.yml` and `.swiftformat` for specific rules.

## Module Dependencies

```
AstraUI (App)
  └─ AstraCore
       └─ AstraData
            └─ AstraPlatform
```

- **No circular dependencies**
- **UI never directly accesses repositories**
- **Services orchestrate business logic**
- **Platform wrappers isolate OS APIs**

## Testing Strategy

- **Unit Tests**: Test individual services in isolation (>95% coverage target)
- **Integration Tests**: Test feature interactions across modules
- **Performance Tests**: Unlock, encryption, UI responsiveness
- **Security Tests**: Confidentiality boundaries, data integrity

## Troubleshooting

### Build Fails with Missing Module
```bash
# Clean build
rm -rf .build/
swift build -v
```

### Tests Don't Run
```bash
# Verify test targets exist
swift test --list

# Run with verbose output
swift test -v
```

### SwiftLint Issues
```bash
# Auto-correct fixable issues
swiftlint autocorrect --path Sources/

# Check specific file
swiftlint Sources/AstraCore/Services/KeyManager.swift
```

## Next Steps

1. **Verify Environment**: Run `swift build` to confirm setup
2. **Check CI/CD**: Push to main branch, watch GitHub Actions
3. **Review Documentation**: Study Requirement.md and ImplementationPlan.md
4. **Begin Phase 1**: Follow Phase 1 tasks in ImplementationPlan.md

## Resources

- [Swift.org](https://swift.org/)
- [SwiftLint GitHub](https://github.com/realm/SwiftLint)
- [SwiftFormat GitHub](https://github.com/nicklockwood/SwiftFormat)
- [AstraNotes Architecture](./AstraNote_Documentations/Architecture.md)
- [AstraNotes Requirements](./AstraNote_Documentations/Requirement.md)

---

**Environment Setup Date**: May 18, 2026
**Swift Version Target**: 5.9+
**macOS Version Target**: 14+ (Sonoma)

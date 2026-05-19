# AstraNotes Quick Start Guide

Get started with AstraNotes development in 5 minutes.

## 1. Verify Your Environment (2 minutes)

```bash
# Check macOS version (need 14+)
sw_vers

# Check Xcode installation
xcode-select --print-path

# Check Swift version (need 5.9+)
swift --version
```

Expected output: Swift version 5.9 or later

## 2. Clone and Navigate (1 minute)

```bash
cd /path/to/AstraNotes
ls -la  # Verify you see Package.swift, Sources/, Tests/
```

## 3. Build the Project (1 minute)

```bash
# Full build
make build

# Or using swift directly
swift build -v
```

You should see output ending with:
```
Build complete!
```

## 4. Run Tests (1 minute)

```bash
# Run all tests
make test

# Or run specific tests
swift test --filter AstraCoreTests -v
```

Expected: All tests pass (currently placeholder tests)

## 5. Code Quality Check (0.5 minutes)

```bash
# Install tools (first time only)
make install-tools

# Check code style
make lint
```

## Verify Complete Setup

✅ **All commands pass**: Your environment is ready!

## Common Commands During Development

```bash
# Build and test
make ci              # Full CI pipeline

# Code quality
make lint            # Check style issues
make lint-fix        # Auto-fix issues
make format          # Format code

# Testing
make test            # Run all tests
make test-core       # Run specific module tests
make coverage        # Generate coverage report

# Cleaning
make clean           # Remove build artifacts
```

## Project Structure Quick Reference

```
Sources/
├── AstraUI/         ← App UI (Phase 4)
├── AstraCore/       ← Services (Phases 1-5)
├── AstraData/       ← Database (Phases 1-2)
└── AstraPlatform/   ← OS APIs (Phases 4-5)

Tests/
├── AstraCoreTests/
├── AstraDataTests/
├── AstraPlatformTests/
└── AstraIntegrationTests/
```

## Next: Begin Implementation

1. Read [DEVELOPMENT.md](./DEVELOPMENT.md) for detailed setup
2. Review [ImplementationPlan.md](./AstraNote_Documentations/ImplementationPlan.md) for Phase 1
3. See [Requirement.md](./AstraNote_Documentations/Requirement.md) for all requirements
4. Check [TestSteps.md](./AstraNote_Documentations/TestSteps.md) for test cases

## Troubleshooting

### Build fails
```bash
rm -rf .build/
swift build -v
```

### Tests won't run
```bash
swift test --list
swift test -v
```

### Can't find SwiftLint
```bash
brew install swiftlint
swiftlint --version
```

## GitHub Actions CI/CD

Once you push to GitHub:
- Automatic build and test runs
- SwiftLint style checks
- Code coverage reports
- Security scans

View status in `.github/workflows/build-and-test.yml`

---

**Ready to start Phase 1? Follow [ImplementationPlan.md](./AstraNote_Documentations/ImplementationPlan.md)!**

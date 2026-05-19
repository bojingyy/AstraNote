.PHONY: help build test clean lint format install-tools ci coverage phase12-validate phase34-validate

help:
	@echo "AstraNotes Development Tasks"
	@echo "============================="
	@echo "make build          - Build all targets"
	@echo "make test           - Run all tests"
	@echo "make test-core      - Run AstraCore tests"
	@echo "make test-data      - Run AstraData tests"
	@echo "make test-platform  - Run AstraPlatform tests"
	@echo "make test-integration - Run integration tests"
	@echo "make phase12-validate - Validate Phase 1/2 with checklist"
	@echo "make phase34-validate - Validate Phase 3/4 with checklist"
	@echo "make coverage       - Generate test coverage report"
	@echo "make lint           - Run SwiftLint checks"
	@echo "make lint-fix       - Auto-fix SwiftLint issues"
	@echo "make format         - Format code with SwiftFormat"
	@echo "make format-check   - Check format without changes"
	@echo "make clean          - Remove build artifacts"
	@echo "make install-tools  - Install SwiftLint and SwiftFormat"
	@echo "make ci             - Run CI pipeline locally"

# Build targets
build:
	@echo "Building AstraNotes..."
	swift build -v

build-release:
	@echo "Building release configuration..."
	swift build -c release -v

# Test targets
test:
	@echo "Running all tests..."
	swift test -v

test-core:
	@echo "Running AstraCore tests..."
	swift test --filter AstraCoreTests -v

test-data:
	@echo "Running AstraData tests..."
	swift test --filter AstraDataTests -v

test-platform:
	@echo "Running AstraPlatform tests..."
	swift test --filter AstraPlatformTests -v

test-integration:
	@echo "Running integration tests..."
	swift test --filter AstraIntegrationTests -v

phase12-validate:
	@echo "=============================================="
	@echo "AstraNotes Phase 1/2 Validation"
	@echo "=============================================="
	@echo "Running Phase 1/2 test gates..."
	@set -e; \
		core_status=PASS; data_status=PASS; int_status=PASS; overall=PASS; \
		echo ""; \
		echo "[1/3] AstraCoreTests (crypto, key lifecycle, lockout)"; \
		if swift test --filter AstraCoreTests >/tmp/astranotes_phase12_core.log 2>&1; then \
			echo "PASS: AstraCoreTests"; \
		else \
			core_status=FAIL; overall=FAIL; \
			echo "FAIL: AstraCoreTests"; \
			cat /tmp/astranotes_phase12_core.log; \
		fi; \
		echo ""; \
		echo "[2/3] AstraDataTests (ACID/transaction/repository behavior)"; \
		if swift test --filter AstraDataTests >/tmp/astranotes_phase12_data.log 2>&1; then \
			echo "PASS: AstraDataTests"; \
		else \
			data_status=FAIL; overall=FAIL; \
			echo "FAIL: AstraDataTests"; \
			cat /tmp/astranotes_phase12_data.log; \
		fi; \
		echo ""; \
		echo "[3/3] Integration test (Phase 1/2 happy path)"; \
		if swift test --filter AstraIntegrationTests.testPhase1And2HappyPathFlow >/tmp/astranotes_phase12_integration.log 2>&1; then \
			echo "PASS: AstraIntegrationTests.testPhase1And2HappyPathFlow"; \
		else \
			int_status=FAIL; overall=FAIL; \
			echo "FAIL: AstraIntegrationTests.testPhase1And2HappyPathFlow"; \
			cat /tmp/astranotes_phase12_integration.log; \
		fi; \
		echo ""; \
		echo "----------------------------------------------"; \
		echo "Requirement Checklist (Phase 1/2 Scope)"; \
		echo "----------------------------------------------"; \
		echo "FR1.1 First-launch passphrase branch............. [$$int_status]"; \
		echo "FR2.1 Note CRUD (create/edit/delete)............. [$$core_status]"; \
		echo "FR2.2 Normal notes stored plaintext............... [$$core_status]"; \
		echo "FR2.3 Stable note IDs............................. [$$core_status]"; \
		echo "FR2.4 Atomic note writes.......................... [$$data_status]"; \
		echo "FR2.5 Delete to trash in ACID transaction......... [$$data_status]"; \
		echo "FR3.1 Secure mode save flow....................... [$$core_status]"; \
		echo "FR3.2 Secure mode requires expiration............. [$$core_status]"; \
		echo "FR3.3 Encrypt secure title/content before storage. [$$core_status]"; \
		echo "FR3.4 Secure note stable IDs...................... [$$core_status]"; \
		echo "FR3.5 Atomic secure writes......................... [$$data_status]"; \
		echo "FR3.8 Reject past expiration timestamp............ [$$core_status]"; \
		echo "FR14.1 Create subject non-empty+unique............ [$$int_status]"; \
		echo "FR14.2 Rename subject non-empty+unique............ [$$core_status]"; \
		echo "FR14.4 Delete subject keeps notes (ungroup)....... [$$data_status]"; \
		echo "NFR4.1 AES-GCM authenticated encryption........... [$$core_status]"; \
		echo "NFR4.2 Verification failure preserves record....... [$$core_status]"; \
		echo "NFR5.1 ACID transactions for writes................ [$$data_status]"; \
		echo "NFR5.2 Failed transaction rollback................. [$$data_status]"; \
		echo "NFR6.1 Rate-limit 5 failures -> lockout........... [$$core_status]"; \
		echo "NFR6.2 Lockout audit logging...................... [$$core_status]"; \
		echo "NFR6.3 Auth failures audit-logged (sanitized)..... [$$core_status]"; \
		echo ""; \
		echo "Overall Phase 1/2 Validation: $$overall"; \
		rm -f /tmp/astranotes_phase12_core.log /tmp/astranotes_phase12_data.log /tmp/astranotes_phase12_integration.log; \
		if [ "$$overall" = "FAIL" ]; then exit 1; fi

phase34-validate:
	@echo "=============================================="
	@echo "AstraNotes Phase 3/4 Validation"
	@echo "=============================================="
	@echo "Running Phase 3/4 test gates..."
	@set -e; \
		core_status=PASS; data_status=PASS; int_status=PASS; overall=PASS; \
		echo ""; \
		echo "[1/3] AstraCoreTests (policy/search/session/attachments)"; \
		if swift test --filter AstraCoreTests >/tmp/astranotes_phase34_core.log 2>&1; then \
			echo "PASS: AstraCoreTests"; \
		else \
			core_status=FAIL; overall=FAIL; \
			echo "FAIL: AstraCoreTests"; \
			cat /tmp/astranotes_phase34_core.log; \
		fi; \
		echo ""; \
		echo "[2/3] AstraDataTests (protected trash repository behavior)"; \
		if swift test --filter AstraDataTests >/tmp/astranotes_phase34_data.log 2>&1; then \
			echo "PASS: AstraDataTests"; \
		else \
			data_status=FAIL; overall=FAIL; \
			echo "FAIL: AstraDataTests"; \
			cat /tmp/astranotes_phase34_data.log; \
		fi; \
		echo ""; \
		echo "[3/3] Integration test (Phase 3/4 secure flow)"; \
		if swift test --filter AstraIntegrationTests.testPhase3And4SecureExpirationTrashAndSearchFlow >/tmp/astranotes_phase34_integration.log 2>&1; then \
			echo "PASS: AstraIntegrationTests.testPhase3And4SecureExpirationTrashAndSearchFlow"; \
		else \
			int_status=FAIL; overall=FAIL; \
			echo "FAIL: AstraIntegrationTests.testPhase3And4SecureExpirationTrashAndSearchFlow"; \
			cat /tmp/astranotes_phase34_integration.log; \
		fi; \
		echo ""; \
		echo "----------------------------------------------"; \
		echo "Requirement Checklist (Phase 3/4 Scope)"; \
		echo "----------------------------------------------"; \
		echo "FR4.1 Expiration checks at launch/active use.... [$$core_status]"; \
		echo "FR4.2 Expired while closed handled on launch..... [$$core_status]"; \
		echo "FR4.3 Expired secure note auto-move to trash..... [$$int_status]"; \
		echo "FR4.4 Foreground/background expiry notifications.. [$$core_status]"; \
		echo "FR4.5 Time rollback guard and deferred checks..... [$$core_status]"; \
		echo "FR5.2 Trash semantics (secure lock badge/no title) [$$int_status]"; \
		echo "FR5.3 Secure title preview blocked in trash....... [$$int_status]"; \
		echo "FR5.4 Restore trashed notes....................... [$$data_status]"; \
		echo "FR5.5 Secure restore requires unlocked session.... [$$core_status]"; \
		echo "FR5.6 Permanently delete trashed note............. [$$data_status]"; \
		echo "FR6.2 Recording follows note security mode........ [$$core_status]"; \
		echo "FR6.3 Reject recording > 50MB..................... [$$core_status]"; \
		echo "FR7.1 Inactivity auto-lock........................ [$$core_status]"; \
		echo "FR7.2 Immediate lock on platform event............ [$$core_status]"; \
		echo "FR7.3 Background ops do not reset inactivity...... [$$core_status]"; \
		echo "FR7.4 Clear key material on lock.................. [$$core_status]"; \
		echo "FR12.1 Title search filters note results.......... [$$core_status]"; \
		echo "FR12.2 Normal title search from storage........... [$$core_status]"; \
		echo "FR12.4 Secure title search while unlocked......... [$$int_status]"; \
		echo "FR12.5 Clear secure search cache on lock.......... [$$core_status]"; \
		echo "FR12.6 Exclude secure search results while locked. [$$int_status]"; \
		echo "FR13.2 Image follows note security mode........... [$$core_status]"; \
		echo "FR13.3 Reject image > 20MB........................ [$$core_status]"; \
		echo "NFR3.2 Secure title cache memory-only + cleared... [$$core_status]"; \
		echo "NFR5.1 ACID writes in trash/expiration flows...... [$$data_status]"; \
		echo ""; \
		echo "Overall Phase 3/4 Validation: $$overall"; \
		rm -f /tmp/astranotes_phase34_core.log /tmp/astranotes_phase34_data.log /tmp/astranotes_phase34_integration.log; \
		if [ "$$overall" = "FAIL" ]; then exit 1; fi

coverage:
	@echo "Generating test coverage report..."
	swift test --enable-code-coverage -v
	@echo "Coverage report generated"

# Code quality targets
lint:
	@echo "Running SwiftLint..."
	swiftlint Sources/ Tests/

lint-fix:
	@echo "Auto-fixing SwiftLint issues..."
	swiftlint autocorrect --path Sources/ --path Tests/

format:
	@echo "Formatting code with SwiftFormat..."
	swiftformat Sources/ Tests/

format-check:
	@echo "Checking format without changes..."
	swiftformat Sources/ Tests/ --dryrun

# Installation targets
install-tools:
	@echo "Installing development tools..."
	brew install swiftlint swiftformat
	@echo "Tools installed successfully"

# Cleaning targets
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .build/
	rm -rf *.xcworkspace/
	find . -name ".DS_Store" -delete
	@echo "Clean complete"

# CI pipeline
ci: clean lint build coverage test
	@echo "CI pipeline complete"

# Continuous development
watch:
	@echo "Watching for changes..."
	swiftlint Sources/ Tests/ --reporter json | json_pp

# Documentation
docs:
	@echo "Building documentation..."
	@echo "See DEVELOPMENT.md for detailed setup guide"

# Pre-commit hook
pre-commit: lint format-check build test
	@echo "Pre-commit checks passed"

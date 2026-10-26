# Gemini & Agent Development Guidelines — IT Box

This document contains critical architectural decisions, engineering standards, and workflow rules for AI agents and developers working on the IT Box repository.

---

## 1. Project Overview & Philosophy

- **Platform**: Android-focused Flutter application (`com.ma.itbox`).
- **Core Mission**: Complete offline IT department operations hub (hardware inventory, network diagnostics, checkouts & borrows, financial ledgers, IPAM, and executive reporting).
- **Offline-First Guarantee**: No external network dependencies, no telemetry SDKs, no cloud databases, and no user sign-ups. All data remains exclusively on the device in SQLite.
- **Persistence Engine**: Compile-time type-safe SQLite database (`itbox.db`) managed via **Drift** (`drift: ^2.35.0`, `sqlite3_flutter_libs: ^0.6.0+eol`) executing in a dedicated background isolate (`NativeDatabase.createInBackground`).
- **Design System**: Fintech Neo-Banking aesthetic with Plus Jakarta Sans typography, tabular numbers (`FontFeature.tabularFigures()`), 18–28px rounded squircles, glowing status pills, and high-contrast AMOLED `#121212` dark mode.

---

## 2. Hard Architectural Rules

1. **NO Third-Party State Management**:
   - Do NOT introduce Provider, Riverpod, Bloc, MobX, or GetX.
   - Use `setState` + `async/await` and native Flutter `StreamSubscription` listening to reactive Drift `.watch()` streams.
2. **NO Dialog-Based Creation/Edit Forms**:
   - All add and edit operations must be full-screen forms pushed via `MaterialPageRoute`.
   - Never put the primary "Save" button in the `AppBar`; place an `ElevatedButton` at the bottom of the scrollable form body.
   - Guard all post-await navigation/setState calls with `if (!mounted) return;`.
3. **Card Surfaces**:
   - Always resolve card container backgrounds with `AppColors.cardSurface(context)`.
   - Never use raw `theme.colorScheme.surface` or inline opacity hacks that break contrast on AMOLED pure black.
4. **Standardized Multi-Selection**:
   - All multi-select inventory and ledger list screens must utilize `SelectionBottomBar` (`lib/widgets/selection_bottom_bar.dart`) for batch select/deselect, deletion, and contextual actions.
5. **Standardized Dropdowns**:
   - Never use raw `DropdownButtonFormField` or unstyled `DropdownButton`. Always use `FintechDropdown<T>` for 16px rounded borders, subtle indicators, and AMOLED-aware menus.
6. **Borrow Nomenclature Rule**:
   - The term "Loan" / "Loans" is **strictly forbidden**. Always use "Borrow" / "Borrows" / "Borrowed" across UI labels, models, database columns, PDF templates, and documentation.
7. **Monospace Security Credentials Typography**:
   - Passwords, Wi-Fi keys, IP addresses, MAC addresses, and hardware serials must use `credentialFont()` (`GoogleFonts.jetBrainsMono()`).
8. **Syntax Consistency**:
   - Never use single-line control flow statements (`if (x) doY();`). Always use curly braces `{ }`.
   - Use `.withValues(alpha: x)` instead of the deprecated `.withOpacity(x)`.

---

## 3. Database & Schema Specifications

- **Current Version**: **Schema v15** (21 lockstep tables).
- **Engine**: SQLite via Drift over Dart FFI in a background isolate.
- **Foreign Keys**: Enforced via `PRAGMA foreign_keys = ON`.
- **Migrations**:
  - Always increment schema version in `lib/database/app_database.dart`.
  - Add new `if (from < N)` migration steps in `onUpgrade`. **Never modify previous migration blocks.**
- **Tables**:
  1. `laptops`
  2. `network_devices` (Routers)
  3. `access_points`
  4. `printers`
  5. `electronics`
  6. `mifis`
  7. `borrow_logs` (Hardware checkout tracking with due dates and overdue alarms)
  8. `expenses` (Ledger with receipt image attachments)
  9. `bills` (Recurring utility bills)
  10. `email_accounts` (Corporate emails)
  11. `log_entries` (IT trouble tickets)
  12. `subscriptions` (SaaS license cycles)
  13. `wifi_networks` (Centralized Wi-Fi credentials vault)
  14. `account_passwords` (Platform logins vault)
  15. `other_devices` (Miscellaneous assets)
  16. `device_maintenance_logs` (Hardware service & repair history)
  17. `consumables` (Toner, cables, parts stock)
  18. `consumable_logs` (Stock adjustments)
  19. `static_ips` (IPAM registry)
  20. `switch_patch_ports` (24/48 port matrix)
  21. `vendor_contacts` (ISP, hardware, and software vendor support runbook with SLA tiers)
- **Multi-Tenant Workspace Isolation**:
  - `WorkspaceService` dynamically switches the active database instance via `AppDatabase.switchDatabaseInstance(dbName)`.
  - Supports separate isolated databases (e.g. `itbox_workspace_<id>.db`) per office or client branch.

---

## 4. Cryptography & Security

- **Backup Encryption**:
  - `BackupCryptoService` implements authenticated **AES-256-GCM** encryption with PBKDF2/Argon2 key derivation and **SHA-256** checksum verification.
  - Backups can be exported as plaintext JSON (`.json`) or encrypted vaults (`.itbox.enc`).
- **Auto-Backup Engine**:
  - `AutoBackupService` executes rolling daily background snapshot checks on app startup and lifecycle resume.
  - Preserves a rolling 7-snapshot retention window and automatically prunes older backups.
- **Credential Protection**:
  - Passwords copied from `AccountsPasswordsScreen` trigger an automatic 60-second clipboard clear timeout.
  - Revealed Wi-Fi passphrases auto-obscure after 30 seconds.

---

## 5. Mandatory Synchronization Workflow

After every task or code update, the following documentation files must be updated to remain in 100% lockstep:
1. `README.md`
2. `CHANGELOG.md` (under the current release section)
3. `STRUCTURE.md`
4. `AI_Instructions.md`
5. `GEMINI.md` (this file)

Before finishing any task, always verify:
```bash
flutter analyze
flutter test
```
All static analysis checks must report **0 issues**, and all unit/integration tests must pass cleanly.

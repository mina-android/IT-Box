# Changelog

All notable changes to IT Box are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) conventions.

> IT Box is the continuation of **Inventorya**. Version 1.0.0 documents the original Inventorya release; 1.0.1 covers the rename and rebranding; the Unreleased section tracks work in progress.

---

## [Unreleased]

---

## [1.0.2] — 2026-07-14

### Added
- **Guided Onboarding Choice & Backup Restoration (`OnboardingScreen`)** — Added a 2-step onboarding screen on initial launch allowing new users to either **Start Fresh** or **Restore Backup (`.json`)**. Restores all 13 database tables and preserves/restores the user's company name (`company_name` added to `exportJson` / `importJson`).
- **Self-Healing Device Status Sync (`syncDeviceStatuses`)** — Added automatic verification when loading `MiFisScreen` or `ElectronicsScreen` and inside `deleteBorrowLog` to instantly reset `mifis` and `electronics` `status` back to `'Available'` if no active `borrow_logs` record exists.
- **Emails Clipboard Copying (`EmailsScreen`)** — Added 1-tap copy buttons (`Icons.copy_outlined`) on every `EmailAccount` list item card and detail bottom sheet (`_showDetail`) for quick copying of both `Email` and `Password` to Android clipboard.
- **Access Points (APs) Inventory Tab & Model (`AccessPointsScreen`, `AccessPoint`)** — Added dedicated inventory tracking for wireless Access Points with Device Number, Model, Port Number, and Location (`itbox.db` schema v8). Fully integrated into Excel import (`importAccessPoints`), export, JSON backup/restore, and barcode label generator (`LabelExportScreen`).
- **Log tab (`LogsScreen`)** — IT issue troubleshooting log with Date, User (employee dropdown), Problem, and Solution fields (`itbox.db` schema v6). Includes year/month filters, search by problem or employee, and Excel (`.xlsx`) import/export (Append or Replace mode).
- **Dashboard / Home Summary (`DashboardScreen`)** — A sleek landing screen (`tab [0]`) providing instant visibility into IT department operations:
  - Live summary counts: **Devices Currently Borrowed**, **This Month's Expenses Total (EGP)**, and **Employees Headcount**.
  - **Quick Actions Grid** with 4 symmetrical buttons (`Borrow Device`, `Emails`, `Bills`, and `Subscriptions`) for rapid task entry.
  - **Interactive Charts (`fl_chart: ^0.68.0`)**: Monthly Expense Trend bar/line chart and Borrow Frequency breakdown by device category.
  - **Side Navigation Drawer (`AppDrawer`)** — Quick jump access to all core modules (`Dashboard`, `Inventory`, `Borrowed`, `Expenses`, `Bills`, `Emails`, `Subscriptions`, `Logs`).
- **Subscriptions Tracking Module (`SubscriptionsScreen`)** — Dedicated feature to record and manage ongoing IT services, SaaS tools, and software licenses:
  - Fields: `service_name`, `type` (`Yearly` | `Monthly` | `Weekly`), `price` (EGP), `renewal_date`, and `notes`.
  - Filter cycle chips (`All`, `Yearly`, `Monthly`, `Weekly`) with real-time monthly and yearly expenditure summary calculations.
  - Persisted in new SQLite `subscriptions` table (`itbox.db` schema v7).
- **Overdue Borrow Tracking & Local Notifications (`NotificationService` + `BorrowedScreen`)** —
  - Added an optional **Due Date (`due_date`)** column to `borrow_logs` (schema v7 migration).
  - Integrated `flutter_local_notifications: ^17.2.3` with Android exact alarm scheduling (`scheduleOverdueNotification`).
  - Automatic local reminder alert when a borrowed device (`electronic` or `mifi`) becomes overdue.
  - Red **OVERDUE** badge highlight on active borrowed cards.
  - Filter borrowed list by `Employee Name` and toggle `Show Overdue Only`.
- **Monthly Expense & Bills PDF Summary Reporting (`PDFReportService`)** —
  - Built alongside existing Excel (`.xlsx`) exports using `pdf: ^3.10.8`.
  - Generates multi-page, professional PDF reports grouping expenses by month and bills by category, complete with EGP subtotals and Grand Totals.
  - Share or open reports instantly (`share_plus: ^8.0.2` & `open_file: ^3.3.2`).
- **Split Release APK Build Optimization** —
  - High-performance, lightweight split per-ABI APK releases (`arm64-v8a`, `armeabi-v7a`, `x86_64`) via `flutter build apk --split-per-abi`, reducing download size to ~30 MB.
- **Pixel-Perfect 100% Full-Bleed Adaptive & Themed Icons** —
  - **Normal Colored App Icon (`ic_launcher_foreground.png`)**: Scaled to **100% full bleed** (`432x432 px` at `xxxhdpi`) across all densities, removing `<inset>` shrink for maximum home screen presence.
  - **Material You Monochrome Icon (`ic_launcher_monochrome.png`)**: Sized with safe margins (`50dp` inside `108dp` canvas with bottom curve breathing room) and clean binary alpha thresholds (`a < 35` transparent, `a >= 35` solid) so dynamic color tinting works flawlessly without clipping the toolbox or wrench curves.

### Changed
- **Dashboard Quick Actions (`DashboardScreen`)** — Replaced the "Log Expense" quick action with **"Emails"** (`Icons.email_outlined`) and replaced the "Inventory" quick action with **"Bills"** (`Icons.receipt_outlined`).
- **Inventory Tabs Spacing (`InventoryScreen`)** — Updated `TabBar` with `isScrollable: false` and `labelPadding: EdgeInsets.zero` so all 6 hardware categories (`Laptops`, `Routers`, `MiFis`, `APs`, `Printers`, `Electronics`) divide 100% of the horizontal screen space evenly without empty gap on the right.
- **Dashboard Stat Cards (`DashboardScreen`)** — Replaced the "Bills Outstanding" card on the Dashboard with an **"Employees"** stat card (`Icons.people_alt_outlined`) to provide immediate visibility into total staff headcount.
- **Inventory Tabs Structure (`InventoryScreen`)** — Renamed the "Network" tab to **"Routers"**, and added the new **"APs"** tab.
- **Smoother & Faster UI Animations** — Upgraded app transitions to use `ZoomPageTransitionsBuilder` (`_fastTransitions` in `AppTheme`) and wrapped `HomeScreen` tab navigation in `AnimatedSwitcher` (`200ms`) for fluid, premium crossfades.
- **Export Barcode Labels Formatting (`LabelService`, `LabelExportScreen`)** — Updated label PDF generation (`printLabels`) to split multi-line labels (`\n`), rendering the phone number on a distinct secondary line in smaller grey text below the device number for both Routers and MiFis.
- **Settings Screen UI (`SettingsScreen`)** — Updated the Import Excel icon arrow to face downward (`Icons.download_outlined`) for intuitive visual consistency.
- **Navigation Structure** — Replaced direct `BorrowedScreen` landing at `tab [0]` with `DashboardScreen`; `HomeScreen` navigation bar updated to 6 tabs (`Dashboard`, `Inventory`, `Borrowed`, `Expenses`, `Log`, `More`).
- **More Screen (`MoreScreen`)** — Added `Subscriptions` management card alongside `Employees`, `Bills`, `Emails`, and `Settings`.
- **Database Schema Version** — Upgraded from `v6` to `v7` (`subscriptions` table) and from `v7` to `v8` (`access_points` table) with automatic non-destructive migration (`_upgrade`).

### Removed
- **Device QR Scanning Module** — Completely removed `mobile_scanner` dependency and check-in/check-out barcode scanner features (`ScannerScreen`) per user request to keep the app lightweight, fast, and focused on offline IT management.

---

## [1.0.1] — 2026-05-24 *(Inventorya → IT Box)*

### Changed
- **App renamed** from Inventorya to **IT Box**
- **Package ID** changed from `com.ma.inventorya` to `com.ma.itbox`
- **Database file** renamed from `inventorya.db` to `itbox.db`
- **App icon** updated to a blue IT toolbox illustration
- **Adaptive/monochrome icon** updated to match Material You spec
- **Backup filename** prefix changed from `inventorya_backup_*.json` to `itbox_backup_*.json`
- **Label PDF filename** prefix changed from `inventorya_*.pdf` to `itbox_*.pdf`
- Settings label "Export Devices" renamed to **Export**
- Settings label "Import Devices" renamed to **Import**
- Import hint text updated to reference IT Box instead of Inventorya
- About section updated to reflect new app name and package

### Added
- **More screen** (new bottom tab) — hub for Employees, Bills, and Settings, replacing the individual bottom-bar entries for those sections
- **Log tab** added to bottom navigation (replaces the Bills slot freed by the More restructure)
- **`log_entries` table** — IT issue log persisted in SQLite (schema v6)
  - Columns: `date`, `employee_id`, `employee_name` (denormalised), `problem`, `solution`
- **LogsScreen** — grouped by month, searchable by problem or employee name, filterable by year and month
- **LogFormScreen** — add/edit log entries with employee dropdown, date picker, problem and solution fields
- **`LogEntry` model** with `toMap()`, `fromMap()`, and `copyWith()`
- **Database migration v5→v6** — creates `log_entries` table on upgrade
- Full **backup/restore coverage** for `log_entries` (included in JSON backup, counted in backup stats)
- `ExcelImportService.importLogEntries()` — parses Date, Employee, Problem, Solution columns; skips blank problem rows; reports per-row errors
- Export support for `log_entries` in `ExcelService` (columns: #, Date, Employee, Problem, Solution)

### Technical
- **Database schema version:** 6 (up from 5)
- Migration: v5→v6 adds `log_entries` table
- `com.ma.inventorya.MainActivity` superseded by `com.ma.itbox.MainActivity`
- Gradle updated to **8.9**, AGP to **8.6.0**, Kotlin JVM target bumped to **17**
- `drawable-v21/launch_background.xml` added for API 21+ launch theming

---

## [1.0.0] — 2026-05-15 *(Initial release as Inventorya)*

### Added
- **Onboarding screen** — first-launch prompt for company name; displayed in Inventory tab header
- **Inventory tab** — 5-sub-tab host screen: Laptops, Network Devices, MiFis, Printers, Electronics
- **Laptops** — track laptop number, model, CPU, GPU, RAM, storage, condition, assigned employee, and password
- **Network Devices** — routers with WiFi name, WiFi password, gateway, admin password, service provider, and borrow status
- **MiFis** — mobile WiFi devices with quota, WiFi/gateway/admin credentials, service provider, and borrow status
- **Printers** — printer inventory with condition and location
- **Electronics** — general electronic devices with borrow status
- **Employees tab** — employee directory with name and phone number
- **Borrowed tab** — track which electronics and MiFis are borrowed, by whom, and when; active and history views
- **Bills tab** — recurring bills by category (MiFis, 4G Internet, Landline Internet, Landline Phone, Mobile Phone) with person, number, price, and notes
- **Emails tab** — email accounts linked to employees with show/hide password toggle
- **Expenses tab** — log expenses by date, grouped by month with yearly totals in EGP
- **Expenses year filter** — year selector in AppBar
- **Expenses export** — From/To date-range export to Excel (.xlsx)
- **Export Devices** — per-category Excel export for all device tables
- **Import Devices** — import Laptops, Network Devices, MiFis, Printers, Electronics, Employees, Bills, and Email Accounts from Excel (.xlsx) with Append or Replace mode
- **Import Expenses** — import expense records from Excel with Append or Replace mode
- **`ExcelImportService`** — date normalisation (yyyy-MM-dd, dd MMM yyyy, Excel serial), header/total row skipping, category validation, per-row error reporting
- **Settings screen** — accessible from every top-level screen via AppBar icon
- **Company name in Settings** — edit anytime; reflected live in Inventory tab header
- **Backup** — full JSON export (all tables) saved via Android SAF file picker
- **Restore** — import from any `.json` backup file
- **Dark mode** — enabled by default, persisted via SharedPreferences
- **Label PDF export** — 3-column device label sheet for all categories; saved to temp dir and shared via `share_plus`
- **Fast page transitions** — `FadeUpwardsPageTransitionsBuilder`

### Changed
- **Laptop "Assigned user"** — now selects from Employees list instead of free-text
- **Borrow device types** — changed from "Network / Electronic" to "Electronic / MiFi"
- **Bills** — date field removed from Bills (not needed for simple bill tracking)
- **Currency** — all monetary values display as EGP throughout Expenses and Bills
- **Navigation** — 6-tab bottom bar: Borrowed, Expenses, Employees, Inventory, Bills, Emails
- **Network Devices fields** — removed `user_or_location`; added WiFi Name, WiFi Password, Gateway, Admin Password
- **Borrow cards** — compact layout, reduced wasted space

### Fixed
- Items not appearing after adding without an app restart (Scaffold + FAB pattern per screen)
- Bills screen stuck on loading (was querying `ORDER BY date DESC` on a removed column)
- Status bar overlap on Expenses and Employees screens (AppBar added)
- Input suggestion popups across all form fields (`enableSuggestions: false`)
- Backup showing "saved" message even when user cancelled the file picker

### Technical
- **Database schema version:** 5
- **Database file:** `inventorya.db`
- **Package:** `com.ma.inventorya`
- Migrations: v1→v2 (network_devices rebuild), v2→v3 (mifis.status column), v3→v4 (bills, email_accounts tables), v4→v5 (bills date column removed)
- `ThemeService` and `CompanyService` converted to singletons
- All `withOpacity()` calls replaced with `withValues(alpha:)` (Flutter 3.27+ requirement)
- All `TextFormField`s set `enableSuggestions: false, autocorrect: false`
- All control-flow blocks enclosed in `{ }` braces
- `DropdownButtonFormField` replaced with `InputDecorator + DropdownButton` (deprecated `value:` param fix)

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| Unreleased | — | Log tab, Log import/export |
| 1.0.1 | 2026-05-24 | Rename to IT Box, new More screen, Log tab infrastructure, DB v6 |
| 1.0.0 | 2026-05-15 | Initial release as Inventorya — full inventory, borrow, expenses, bills, emails, export/import |

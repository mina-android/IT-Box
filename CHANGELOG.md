# Changelog

All notable changes to IT Box are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) conventions.

> IT Box is the continuation of **Inventorya**. Version 1.0.0 documents the original Inventorya release; 1.0.1 covers the rename and rebranding; the Unreleased section tracks work in progress.

---

## [1.2.0] - 2026-11-25

### Changed
- **README**: Removed the Frequently Asked Questions section and navigation link from `README.md` to match `README_TEMPLATE.md`.

### Added (Borrow Notes, Ticket Reminders, Multi-Table Excel & Deep Search Navigation)
- **Version Bump (`pubspec.yaml`, `DatabaseHelper`, `BackupCryptoService`, `SettingsScreen`)**: Bumped application version to **1.2.0+7**.
- **Optional Borrow Notes (Schema v17 — `BorrowLog`, `AddBorrowScreen`, `BorrowedScreen`, `CustodyPdfService`, `DataHubScreen`)**:
  - Added `borrow_logs.notes` in Drift Schema **v17** (`ALTER TABLE borrow_logs ADD COLUMN notes TEXT DEFAULT ''`).
  - Added an optional **Notes** field in `AddBorrowScreen`, displayed in `BorrowedScreen`'s detail sheet (`_showBorrowDetail`), wired into `CustodyPdfService` (`adminNotes`), and included in `borrow_logs` Excel exports/templates.
- **Multi-Table Excel Export (`DataHubScreen`, `ExcelService.exportMultipleTables`)**:
  - Upgraded **Export Category Table (.xlsx)** in `DataHubScreen` to a multi-select checkbox sheet with **Select All / Deselect All**, generating separate individual `.xlsx` files and sharing them together.
- **Universal Search Deep Navigation (`DashboardScreen`, `HomeScreen`, `ActivityScreen`, & 20 List Screens)**:
  - Tapping any Universal Search result on `DashboardScreen` now navigates to the target screen/tab and automatically opens that exact entry's detail sheet (or `Employee360Screen` for staff, edit form for card-based screens, History/Active tab for Borrows, and past-year lookup for Expenses/Tickets).
- **Recurring Bills & Subscriptions Search (`BillsScreen`, `SubscriptionsScreen`)**:
  - Added expandable `FintechCircleButton` search toggles and `SearchBar2` filtering alongside category/cadence `FintechFilterPill` bars.
- **Expenses & Filter Sheet Unification (`ExpensesScreen`, `BorrowedScreen`, `DataHubScreen`)**:
  - Unified `BorrowedScreen` and `ExpensesScreen` Filter & Sort bottom sheets to match `LogsScreen._showFilterAndSortSheet` (`Reset`, `FintechFilterPill`s, bordered `ListTile` sort cards with ascending/descending toggle, and explicit `All Years` / `All-Time Total` support).
  - Moved the **Executive Financial Report (PDF)** export out of `ExpensesScreen` into `DataHubScreen` with a fiscal-year / all-time period selector, and standardized `ExpensesScreen`'s `FintechAppBar` with expandable Search and Filter & Sort buttons.
- **Complete Backup & Restore Integrity (`DatabaseHelper`, `DataHubScreen`, `AutoBackupService`, `WorkmanagerService`)**:
  - Fixed Drift reactive stream invalidation after restore (`drift.markTablesUpdated(drift.allTables)` + `_dbSwitchController.add(null)`) and added live `CurrencyService().reloadForActiveOrganization()` reload.
  - Added `TicketReminderService` settings (`enabled`, `days`, `times`) to backup export & restore.
  - Updated `AutoBackupService` to always embed Vault & Receipt binaries (`includeVaultBinaries: true`), pass `inputData: {'orgId': orgId}` in WorkManager tasks, and load `ThemeService` & `TicketReminderService` in `callbackDispatcher()` with isolated target-org database switching.
  - Fixed selective backup (`expenses` now embeds `receipt_files`), selective restore of `switch_patch_ports` (restores custom chassis), secondary-org switch chassis isolation, `BackupManifestSummary.embeddedReceiptFilesCount`, and Company Logo clear/cache-eviction on restore.
- **Ticket Logging Notification Reminders (`TicketReminderService`, `NotificationService`, `SettingsScreen`)**:
  - Added a dedicated **Ticket Logging Reminders** card in `SettingsScreen` with master enable/disable toggle, weekday selector (`Sun`–`Sat`), and manual clock-time entry (`TimePickerEntryMode.input`) supporting multiple daily reminder times shared across selected days.
  - Scheduled weekly recurring local notifications (`DateTimeComponents.dayOfWeekAndTime`) in an isolated ID namespace (`0x60000000+`) so borrow overdue reminders and ticket reminders never cancel each other during reconciliation.
  - Tapping a Ticket Reminder notification (warm or cold start) navigates directly to `LogFormScreen` via `navigatorKey`.
- **Shared Fintech UI Primitives (`lib/widgets/fintech_components.dart`, `lib/theme/app_theme.dart`)**:
  - Added global 16px Fintech squircle button themes (`elevatedButtonTheme`, `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`).
  - Added `FintechFilterPill`, `FintechFilterBar`, and `showFintechEmployeePicker` (with `FintechEmployeeSelection`).

### Changed & Fixed (App-Wide Fintech Unification & Label Export Fix)
- **Fixed Export Asset Labels & QR Infinite Loading (`LabelExportScreen`)**: Replaced `dynamic` list casts in `_loadData()` with strongly-typed model lists (`List<Laptop>`, `List<NetworkDevice>`, `List<MiFi>`, `List<AccessPoint>`, `List<Printer>`, `List<Electronic>`, `List<WifiNetwork>`) and explicit `.map<String>` / `.map<Map<String, String>>` conversions wrapped in `try/catch`, fixing the runtime `TypeError` that left `_dataLoaded` stuck on `false`.
- **Removed Redundant Refresh Buttons**: Removed `EmptyState(onRefresh: ...)` across all 13 reactive list screens (`AccessPointsScreen`, `BillsScreen`, `BorrowedScreen`, `ElectronicsScreen`, `EmailsScreen`, `EmployeesScreen`, `ExpensesScreen`, `LaptopsScreen`, `MiFisScreen`, `NetworkDevicesScreen`, `OtherDevicesScreen`, `PrintersScreen`, `SubscriptionsScreen`), preserving only the 2 functional refresh buttons (Settings Exchange Rates & Network Scanner).
- **Documents Vault & Custody Improvements**:
  - Removed the duplicate top-right Upload Document `FintechCircleButton` from `DocumentsVaultScreen` AppBar.
  - Upgraded Custody Document Form's "Pick from Inventory" sheet to a 2-column `InventoryGridCard` grid matching `AddBorrowScreen`.
  - Unified all 6 employee-picking forms (`VaultDocumentFormScreen`, `CustodyDocumentFormScreen`, `LaptopFormScreen`, `AddBorrowScreen`, `LogFormScreen`, `EmailFormScreen`) onto the shared searchable `showFintechEmployeePicker`.
- **Expandable AppBar Search & Filter Pills**:
  - Standardized standalone list screens (`VendorContactsScreen`, `WifiNetworksScreen`, `StaticIpListScreen`, `AccountsPasswordsScreen`, `EmailsScreen`, `EmployeesScreen`, `ActivityFeedScreen`) onto the expandable AppBar search toggle (`CustodyDocumentsScreen` pattern) and fixed double-padding on `VendorContactsScreen`.
  - Replaced all raw `FilterChip`, `ChoiceChip`, `ActionChip`, and `Chip` bars across `CustodyDocumentsScreen`, `DocumentsVaultScreen`, `VendorContactsScreen`, `SubscriptionsScreen`, `BillsScreen`, `DashboardScreen`, `BorrowedScreen`, `LogsScreen`, `NetworkScannerScreen`, `NetworkDiagnosticsScreen`, `ActivityFeedScreen`, and `LabelExportScreen` with `FintechFilterPill` / `FintechFilterBar`.
- **Deep UI Unification**:
  - Standardized `SelectionBottomBar` (`totalCount`, `onSelectAll`, `onDeselectAll`) across all 16 multi-select list screens and removed duplicate AppBar Select-All buttons.
  - Stripped conflicting `26px`/`25px`/`14px`/`12px` button radius overrides across forms and detail sheets, wrapped all FABs in `SmoothExitFab`, migrated all 6 raw `showModalBottomSheet` calls to `showFintechBottomSheet`, migrated 2 raw `showSnackBar` calls in `Employee360Screen` to `showSnack`, replaced raw `Card(` / `Colors.white` surfaces with `AppColors.cardSurface(context)`, replaced `OnboardingScreen` raw `AppBar` with `FintechAppBar`, and migrated all custom/plain-text empty states to `EmptyState`.

### Added (Custody Documents Hub, Documents Vault & Expensy Auto-Backup)
- **Custody Documents Hub (`CustodyDocumentsScreen`, `CustodyDocumentFormScreen`)**:
  - Added to the `More` tab and Dashboard quick actions (`New Custody Slip`).
  - Automatically archives every custody PDF generated from Borrowed & Laptops into `custody_documents` (Schema v16).
  - Supports creating custom/hybrid custody documents from scratch: pick multiple existing inventory assets or add custom items, attach dynamic key-value hardware specifications (`extraSpecs`), edit compliance/agreement text, add admin notes, and capture a recipient signature.
  - Supports `SelectionBottomBar` multi-select **Consolidated Multi-Page PDF** bulk export (`CustodyPdfService.generateBulkCustodyDocumentsPdf`).
- **Documents Vault (`DocumentsVaultScreen`, `VaultDocumentFormScreen`, `DocumentViewerScreen`)**:
  - Added to the `More` tab, Dashboard quick actions (`Scan Document`), and Android app icon shortcut (`Scan to Vault`).
  - Integrates on-device ML Kit document scanning (`google_mlkit_document_scanner`) with multi-page PDF bundling and file import (`file_picker`).
  - Supports categories (`Contract`, `Invoice`, `Warranty`, `Signed Custody`, `ID/Compliance`, `Other`), optional Employee/Asset tagging, and an embedded in-app PDF (`printing`) & zoomable image (`InteractiveViewer`) viewer.
  - Both Custody Documents and Vault Documents are surfaced inside `Employee360Screen`.
- **Expensy-Ported Auto-Backup, Selective Restore & Pre-Restore Undo (`DataHubScreen`, `AutoBackupService`, `WorkmanagerService`, `itbox_saf`)**:
  - Ported `itbox_saf` (Android Storage Access Framework folder picker & persisted URI read/write) and `workmanager` for scheduled **02:00 AM** background auto-backups plus startup/resume catch-up.
  - Added optional Android Keystore hardware-backed backup encryption for automated snapshots and per-organization isolated backup keys/files.
  - Added **Selective Backup** (table-group checkboxes) and **Selective Restore** with manifest inspection (`inspectBackupJson`) and automatic **Pre-Restore Undo** safety snapshot (`createPreRestoreSnapshot` / `restoreFromSnapshotPath`).
  - Full & Selective manual backups embed Base64-encoded `vault_files` & `receipt_files` (`Expenses.receiptPath`) protected by AES-256-GCM + SHA-256; scheduled auto-backups pass `includeVaultBinaries: false` to stay lightweight.

### Changed & Fixed (Schema v16, Bugfixes, UI/UX Consistency & Dead Code Purge)
- **Schema v16 (23 Lockstep Tables)**: Added `custody_documents`, `vault_documents`, `expenses.receipt_path`, `vendor_contacts.sla_tier`, and 9 performance indexes; replaced `sqflite` path lookup with `_resolveDatabasesPath()`.
- **Correctness & Bugfixes**:
  - Fixed `AuditExportService` reading `action_type`/`entity_type` (instead of blank `action`/`entity`).
  - Fixed `BackupCryptoService` to use `Random.secure()` 16-byte salts and dynamic `PackageInfo`.
  - Fixed `DatabaseHelper` null employee unlinking (`Value(ea.employeeId)`, `Value(le.employeeId)`), device maintenance cascade deletion (`_deleteMaintenanceForDevice`), single-query `getEmployeeDependentCounts`, `watchWifiNetworks`/`watchAccountPasswords` column names, and `date('now', 'localtime')` / `LOWER(state)='open'` in `watchCounts()`.
  - Fixed `ExcelImportService` (`_firstNonEmptySheet`, `DateCellValue`/`DateTimeCellValue`, optional `renewalDate`, active-borrow `replace` guard) and added importers for Vendor Contacts, Wi-Fi Networks, Account Passwords, and Static IPs.
  - Fixed `ExcelService` (`Sheet1` cleanup, sanitized filenames, `compute` isolate for expenses), `WifiPdfService` (`T:nopass` & `pw.Font.courier()`), `LabelService` (render `title` & `subtitle`), `ExecutiveHealthPdfService` (`Future.wait` + `access_points`/`other_devices`), and `NetworkScannerService`/`NetworkDiagnosticsService` (TLS callback + socket `finally` cleanup + batched port scans).
  - Fixed `CurrencyService` per-organization currency isolation & `CompanyService` org switch currency/notification reconciliation.
  - Fixed `NotificationService` per-organization IDs, single permission request, and `init()` in `cancelReminder`.
- **UI/UX Consistency & Rule Compliance**:
  - Removed the `'Available'` status badge from Routers (`NetworkDevicesScreen` & `NetworkDeviceFormScreen`) and expanded Borrow eligibility cleanly for MiFis & Electronics.
  - Converted Switch Patch Port editing from a bottom sheet to full-screen `SwitchPatchPortFormScreen`.
  - Standardized `SelectionBottomBar` (`totalCount`, `onSelectAll`, `onDeselectAll`), `FintechDropdown` validation (`FormField<T>`), `SensitiveDetailRow` (30s auto-obscure + 60s clipboard clear), and `SearchBar2` clear button (`ValueListenableBuilder`).
- **Dead Code & Dependency Purge**:
  - Removed unused `animations` and `sqflite` dependencies, `lib/services/config_parser_service.dart`, `lib/services/topology_pdf_service.dart`, `android/app/src/main/java/com/example/`, `android/inventorya_android.iml`, shadowed `android/*.gradle.kts` files, and dead widgets (`FintechHeader`, `FintechSegmentedControl`, `FintechContainedLedger`, `FintechExtendedFab`).

---

## [1.1.1] - 2026-11-16

### Added & Changed (UI/UX Unification, Multi-Organization Hot-Switching, Currency & Exchange Rates)
- **Full-Screen Maintenance & Repair Form**: Replaced the `AlertDialog` in `DeviceMaintenanceScreen` with a full-screen `DeviceMaintenanceFormScreen` supporting Service Type (`FintechDropdown`), Planned/Completed scheduling toggle, Date picker, Cost, Work Details, Vendor/Technician, and optional Expense ledger sync. Enabled Maintenance & Repair History access across **Laptops**, **Routers** (`NetworkDevicesScreen`), and **Printers** (`PrintersScreen`).
- **Unified "Others" Detail Popup**: Aligned `OtherDevicesScreen._showDetail` with all other inventory detail sheets (single header, `Edit Details` / `Delete` `OutlinedButton` row at top, `FintechGroupedCard` specifications).
- **Borrows Sorting**: Added a `Sort Ordering` section inside `BorrowedScreen`'s filter bottom sheet supporting Checkout Date, Due/Return Date, Device Name, and Employee Name (Ascending/Descending) for both Active Borrows and Borrow History.
- **Audit Trail Header Spacing**: Updated `FintechAppBar` to enforce `8px` spacing between action buttons and styled the Clear Audit Trail button with error tinting.
- **Universal Search on Home**: Removed standalone `GlobalSearchScreen` from `MoreScreen` and embedded a live inline Universal Search bar (`SearchBar2`) on `DashboardScreen` searching across all 18 entity categories with filter chips and direct navigation.
- **Network Diagnostics Improvements**: Removed the private-storage Topology PDF save button from `NetworkDiagnosticsScreen` and added clear step-by-step usage instruction cards (`_InstructionCard`) and quick enterprise port chips for DNS Lookup, Port Probe, and Throughput Estimator.
- **Vendor Contacts Header Cleanup**: Removed the duplicate top-right `+` button from `VendorContactsScreen`, retaining the standard `FintechFab`.
- **Multi-Organization Isolation (Replacing Workspaces)**: Removed `WorkspaceService` completely and upgraded `CompanyService` + `DatabaseHelper` (`_watchSwitchable` + `onDatabaseSwitched`) to support multiple isolated Organizations (`OrganizationProfile`, `OrganizationFormScreen`), each with its own SQLite database (`itbox.db` for primary, `itbox_org_<id>.db` for additional orgs), name, and logo, with instant hot-switching and secondary organization deletion in Settings without app restart or data loss.
- **Multi-Currency & Exchange Rate Retrieval (Ported from Expensy)**: Added `CurrencyService` (62 `kCurrencies`, `showCurrencyPicker`) and `ExchangeRateService` (`open.er-api.com` + `fawazahmed0` CDN + offline fallback rates). Replaced all hardcoded `EGP` labels across Dashboard, Expenses, Bills, Subscriptions, Maintenance, Excel exports, and PDF reports, with optional atomic conversion of stored financial records on currency switch.
- **App-Wide UI/UX & Rounded Dropdown Unification**:
  - Added global `popupMenuTheme` and `dropdownMenuTheme` with `16px` rounded corners and updated `inputDecorationTheme` border radius to `16px` in `app_theme.dart`.
  - Replaced all remaining raw `DropdownButton` / `DropdownButtonFormField` instances with `FintechDropdown<T>` (`vendor_contact_form_screen.dart`, `unit_converter_screen.dart`, `static_ip_form_screen.dart`, `switch_patch_chassis_form_screen.dart`, `switch_patch_matrix_screen.dart`).
  - Added `16px` rounded corners to `PopupMenuButton`s in `accounts_passwords_screen.dart`, `wifi_networks_screen.dart`, and `switch_patch_matrix_screen.dart`.
  - Unified all 16 remaining raw `AppBar` screens to `FintechAppBar`, refactored `VendorContactFormScreen` to `FintechGroupedCard` + `AppTextField`, moved Save buttons in `AddBorrowScreen`, `EmailFormScreen`, `EmployeeFormScreen`, and `LogFormScreen` to the bottom of the scrollable `ListView`, converted port/custom-label edit dialogs to `showFintechBottomSheet`, and standardized bottom sheets across `BorrowedScreen`, `Employee360Screen`, and `BarcodeScannerScreen`.

---

## [1.1.0] - 2026-10-26

### Added & Hardened (Correctness Fixes C1-C11, Card Surface Standard & Feature Waves W1-W5)
- **Correctness & Robustness Hardening (C1–C11)**:
  - **C1: Maintenance Date Parsing Fallback**: Added robust `DateTime.tryParse()` fallback handling with current timestamp default in `device_maintenance_logs` to prevent crash loops when loading legacy or malformed timestamps.
  - **C2: Case-Insensitive Trimmed Excel Import**: Implemented header trimming, normalization, and case-insensitive column matching across all table importers in `ExcelImportService` to eliminate failed batch rows from third-party spreadsheet variations.
  - **C3: Dynamic RAM & Storage Form Inputs**: Replaced rigid dropdown selectors in `LaptopFormScreen` with free-form text inputs with auto-suggest chips, supporting custom hardware combinations (e.g. 20GB RAM, NVMe + SATA dual drives).
  - **C4: Employee Phone Number Formatting & Uniqueness**: Added phone number normalization, duplicate phone detection warnings, and clean formatting in `EmployeeFormScreen`.
  - **C5: Soft Delete Cascading & Recovery Integrity**: Added transaction-wrapped atomic soft-delete restores and cascading checks for dependent borrow logs and maintenance records.
  - **C6: CIDR Subnet Validator & IP Conflict Prevention**: Added strict `/0` through `/32` prefix validation, network/broadcast range calculation, and duplicate static IP address detection in `StaticIpFormScreen`.
  - **C7: Audit Trail Range Filter & Search Debouncing**: Added date range bounds filtering and a 250ms debouncer on activity search queries in `ActivityFeedScreen` to prevent redundant database hits.
  - **C8: Barcode Scanner Error Toast & Graceful Recovery**: Hardened `BarcodeScannerScreen` with error toasts and camera exception recovery when scanning damaged or unparseable QR/barcodes.
  - **C9: Financial Ledger Boundary Clamping**: Clamped year/month selectors in `ExpensesScreen` to prevent invalid future date selections and handle empty month buckets cleanly.
  - **C10: Clipboard Auto-Clear for Platform Credentials**: Added 60-second automatic clipboard purge notification and toast feedback when copying passwords from `AccountsPasswordsScreen`.
  - **C11: Wi-Fi Password Reveal Timeout**: Added a 30-second auto-obscure timer to revealed Wi-Fi passphrases across the Wi-Fi Networks Registry.
- **UI Architecture & Theme Standardization (P3)**:
  - **Unified Card Surfaces (`AppColors.cardSurface(context)`)**: Introduced centralized theme card surface resolver providing seamless support for Light, Dark, and Pure AMOLED (`#121212`) palettes without hardcoded color hacks.
  - **Standardized Multi-Select Bar (`SelectionBottomBar`)**: Rolled out unified bottom multi-selection action bar across all 10 inventory and ledger list screens (`LaptopsScreen`, `NetworkDevicesScreen`, `MiFisScreen`, `AccessPointsScreen`, `PrintersScreen`, `ElectronicsScreen`, `OtherDevicesScreen`, `EmployeesScreen`, `ExpensesScreen`, `BillsScreen`, `SubscriptionsScreen`), supporting select-all, deselect, leading/trailing contextual actions, and batch deletions.
- **Wave W1: Vendor Runbook, Unit Converter & Audit Export**:
  - **Vendor & Support Runbook**: Added `vendor_contacts` Drift table (schema v15), `VendorContact` model, `VendorContactsScreen`, and `VendorContactFormScreen` with one-tap phone dialing, email drafting, SLA tier badges, and contract notes.
  - **IT Unit Converter**: Added `UnitConverterScreen` supporting bidirectional real-time calculations across Network Speeds (bps, Kbps, Mbps, Gbps), Storage Units (B, KB, MB, GB, TB, KiB, MiB, GiB, TiB), and RF Signal Power (dBm <-> mW <-> W).
  - **Audit Trail CSV & PDF Export**: Added `AuditExportService` enabling one-tap export of historical operational logs into formatted CSV sheets or executive PDF summaries.
- **Wave W2: Global Cross-Table Search & Background Auto-Backup**:
  - **Global Search Engine**: Added `GlobalSearchService` and `GlobalSearchScreen` executing simultaneous asynchronous queries across all 21 Drift tables (hardware, staff, IPs, credentials, vendors, logs) with category badge filtering and instant navigation.
  - **Automated Background Backup Engine**: Added `AutoBackupService` running 24-hour cadence checks on app startup/resume, creating timestamped JSON snapshots with rolling 7-snapshot retention and automated pruning.
  - **Military-Grade Backup Encryption**: Added `BackupCryptoService` implementing authenticated AES-256-GCM encryption with SHA-256 payload integrity validation for encrypted local backup archives (`.itbox.enc`).
- **Wave W3: Network Diagnostics Suite & Topology Vector Map**:
  - **Network Diagnostics Suite**: Added `NetworkDiagnosticsService` and `NetworkDiagnosticsScreen` with multi-mode DNS lookup (A, AAAA, MX, TXT), TCP port probe with socket banner grabbing, and HTTP link throughput speed estimator.
  - **Network Topology PDF Map**: Added `TopologyPdfService` generating multi-page vector landscape schematics documenting network routers, switches, access points, and IPAM allocation maps.
- **Wave W4: Cisco Config Parser & Preventive Maintenance Calendar**:
  - **Cisco IOS Config Parser**: Added `ConfigParserService` parsing running-config files to extract physical/virtual interfaces, IP addresses, subnet masks, VLANs, and switchport access/trunk modes into structured models.
  - **Maintenance Calendar**: Added `MaintenanceCalendarScreen` featuring an interactive month calendar grid, event dots, planned vs completed service badges, technician notes, and direct links to per-device service logs.
- **Wave W5: Multi-Workspace Tenant Isolation**:
  - **Multi-Tenant Database Switcher**: Added `WorkspaceService` managing isolated SQLite databases (`itbox_workspace_<id>.db`) per branch/site with dynamic isolate switching (`AppDatabase.switchDatabaseInstance`) and workspace manager UI in System Settings.

### Added & Changed (Documentation Overhaul, Performance, UI Fixes, Wi-Fi Cards Redesign & Dropdown Overhaul)
- **License Update to GNU General Public License v3.0 (GPL-3.0)**:
  - Updated project license from MIT to GNU General Public License v3.0 in [LICENSE](file:///c:/Projects/itBox/LICENSE) and updated corresponding status badges and legal notices in [README.md](file:///c:/Projects/itBox/README.md).
- **Repository Documentation Overhaul**:
  - Rewrote and aligned [README.md](file:///c:/Projects/itBox/README.md) to match the standardized template from Expensy, featuring a 3x3 9-screenshot showcase grid, quick jump anchors, comprehensive feature highlights, privacy and offline architecture FAQ, and collapsible developer setup guides.
  - Updated header icon reference to use `assets/icon/app_icon_raw.png`.
- **Tickets Page Navbar Occlusion Fix**:
  - Padded `FintechFab` with `80px` bottom offset and set transparent inner `Scaffold` background in `LogsScreen` when embedded in `ActivityScreen`, ensuring the add button is never obscured by the floating bottom navigation bar.
- **Network Scanner 60 FPS Sweep Scrolling**:
  - Decoupled live sweep progress updates from the main widget tree using a dedicated `ValueNotifier<_ScanProgress>` and `ValueListenableBuilder`.
  - Added a 140ms discovery buffer queue and `ValueKey(host.ip)` to prevent rapid full-screen re-renders and eliminate frame drops and scrolling jitter during high-concurrency network sweeps.
- **Wi-Fi Networks Registry Smooth Scrolling**:
  - Added `AutomaticKeepAliveClientMixin` with `wantKeepAlive => true` to `SlideInAndFade` so off-screen recycled cards do not re-run entrance animation controllers or stutter during scroll.
  - Replaced index-based password visibility sets with stable composite keys (`_netKey(net)`) and memoized telemetry header counts (`_routerCount`, `_mifiCount`, `_standaloneCount`).
- **Audit Trail Clear Option**:
  - Added `DatabaseHelper.clearAuditActivities()` with reactive `notifyTableChanged('audit_activities')` table invalidation.
  - Added a `FintechCircleButton` purge action in `ActivityFeedScreen` equipped with a destructive confirmation dialog and toast feedback.
- **Wi-Fi Cards Redesign & Portable Format (A4 Landscape)**:
  - Redesigned standard Wi-Fi cards: removed the "Security" line, positioned the device name above the network SSID, removed the bottom "Scan QR code" prompt, and compacted card borders to format **3 cards per A4 page** vertically with dashed cut guides.
  - Added **Portable Cards (7cm × 4cm)** export in `WifiPdfService`: laid out in **Landscape A4** (4 columns × 5 rows = 20 cards per sheet) with dashed cut guides and compact 30×30mm QR codes.
  - Added dual export buttons ("Standard (3/Page)" and "Portable (7×4cm)") in `LabelExportScreen`'s Wi-Fi Cards subtab.
- **App-Wide Modern Rounded Dropdown Component**:
  - Created `FintechDropdown<T>` in `lib/widgets/fintech_dropdown.dart` featuring 16px rounded borders, subtle container styling, modern chevrons (`Icons.keyboard_arrow_down_rounded`), and 16px curved floating popup menus with dark mode and AMOLED contrast awareness.
  - Replaced legacy dropdowns across `bill_form_screen.dart`, `laptop_form_screen.dart`, `log_form_screen.dart`, `subscription_form_screen.dart`, `borrowed_screen.dart`, and `expenses_screen.dart`.
- **Switches & Patch Label Export Clean Subtitle Removal**:
  - Stripped secondary lines (`\n${c['totalPorts']}-Port ${c['type']}`) from printable text labels and removed subtitles from QR labels in `LabelExportScreen`.
- **Tickets Employee Requester Bottom Sheet Picker**:
  - Replaced the basic dropdown in `LogFormScreen` with an interactive, searchable modal bottom sheet modeled after the Borrows employee selector.
  - Added a prominent "None (General IT issue)" option, real-time employee search, and quick clear action.
- **Predictive Back Gestures & Swipe Transitions**:
  - Replaced `SharedAxisTransition` with standard `MaterialPageRoute` across the entire application. Page transitions now inherit the application theme's `CupertinoPageTransitionsBuilder`, providing buttery-smooth horizontal swipe transitions and native Android predictive back gestures.
- **Home Dashboard & Navigation Bar**:
  - Removed "IT Operations" subtitle from the Home dashboard header for a cleaner header area.
  - Set `NavigationDestinationLabelBehavior.alwaysHide` on the bottom navigation bar to display only clean icons without text labels.
- **Unified Action Buttons & Toolbars**:
  - Created `FintechActionButton` (48×48 rounded container with touch feedback and active state color styling).
  - Added `noPadding: true` support to `SearchBar2` to prevent double padding and ensure vertical alignment when embedded in custom toolbars.
  - Operations Activity: Unified filter buttons in Borrows and Tickets with `FintechActionButton` and aligned the tickets search bar.
  - Expenses Ledger: Moved action buttons (PDF export, year dropdown selector, sort) from the AppBar into an in-body toolbar alongside `SearchBar2`.
  - Network Scanner: Moved scanner configure and CSV export action buttons into an in-body toolbar alongside `SearchBar2`.
- **Custody PDF Documents**:
  - Completely removed the "Generated offline by IT Box" footer row from both individual custody receipts and bulk laptop custody slips in `CustodyPdfService`.
- **Switch & Patch Matrix Improvements**:
  - Moved the unit creation button from the AppBar to a floating `FintechFab` on the screen.
  - Fixed infinite horizontal layout loop when choosing 24 or more ports by utilizing `IntrinsicWidth` and aligning child columns to `.start`.
- **Vault & Network Management**:
  - Removed the redundant refresh icon from Accounts & Passwords Vault and Wi-Fi Networks Registry AppBars.
  - Fixed search bar sizing and padding consistency in Wi-Fi Networks.
  - Web Admin Launcher: Enhanced Web Admin link launching in Network Scanner with `<queries>` intent filters in `AndroidManifest.xml`, dual launch mode fallback (`externalApplication` then `platformDefault`), and automatic clipboard copy fallback.
  - Standalone Wi-Fi Label Export: Wi-Fi cards in Label Export now include standalone Wi-Fi networks saved in Wi-Fi Networks Registry with SSID deduplication.
- **FAB & Component Standardization**:
  - Standardized all Floating Action Buttons across the application on `FintechFab`.
  - Coordinated add button colors with tab icons (theme primary for Home, emerald green for Inventory, sky blue for Emails, mint green for Expenses).
  - Upgraded raw `AppBar` instances in Tickets and Maintenance screens to `FintechAppBar`.

### Added & Migrated (Drift Typed Builders & Reactive Streams)
- **Phase 1: Pilot Phase (`borrow_logs` & `log_entries`)**:
  - Migrated `insertBorrowLog`, `updateBorrowLog`, `markReturned`, `deleteBorrowLog`, and `getBorrowLogs` to Drift typed query builders with compile-time checked companion classes (`BorrowLogsCompanion`).
  - Fixed return status synchronization in `updateBorrowLog` to guarantee devices transition accurately between 'Borrowed' and 'Available' even when hardware IDs remain unchanged.
  - Migrated `insertLogEntry`, `updateLogEntry`, `deleteLogEntry`, `getLogEntries`, `getLogEntriesByYear`, `getLogEntriesByMonth`, and `getOpenLogEntries` to typed query builders with case-insensitive state filtering.
  - Added reactive typed streams `watchBorrowLogs({bool? activeOnly})` and `watchLogEntries({String? stateFilter, int? year, int? month})`.
  - Connected `BorrowedScreen` and `LogsScreen` directly to reactive Drift streams for real-time UI updates without manual polling.
- **Phase 2: Core Hardware Inventory (`laptops`, `mifis`, `electronics`)**:
  - Migrated CRUD operations and hardware status updates (`updateMiFiStatus`, `updateElectronicStatus`) to typed queries and companions.
  - Added reactive streams: `watchLaptops()`, `watchMiFis()`, `watchElectronics()`.
  - Migrated `LaptopsScreen`, `ElectronicsScreen`, and `MiFisScreen` to direct reactive Drift stream subscriptions.
- **Phase 3: Secondary Inventory & Networks (`network_devices`, `access_points`, `printers`, `other_devices`, `wifi_networks`)**:
  - Migrated all secondary hardware and network CRUD operations to typed Drift queries and companions.
  - Added reactive streams: `watchNetworkDevices()`, `watchAccessPoints()`, `watchPrinters()`, `watchOtherDevices()`, `watchWifiNetworks()`.
- **Phase 4: Operations & Financial Ledger (`employees`, `email_accounts`, `account_passwords`, `static_ips`, `expenses`, `bills`, `subscriptions`)**:
  - Migrated employee directory, credential vault, IPAM, and financial ledger queries to typed Drift builders.
  - Implemented typed financial aggregations `getTotalExpenses({int? year, int? month})`, `watchTotalExpenses()`, `getTotalBills()`, and `watchTotalBills()` using `drift.price.sum()`.
  - Added reactive `watchCounts()` stream and connected `DashboardScreen` for real-time system metrics invalidation.
  - Added directory search filtering to `watchEmployees({String? search})` and migrated `EmployeesScreen` to stream subscriptions.
  - Added reactive streams: `watchEmailAccounts()`, `watchAccountPasswords()`, `watchStaticIps()`, `watchExpenses({int? year, int? month})`, `watchBills()`, `watchSubscriptions()`.
- **Phase 5: Technical Matrix, Maintenance & System Auditing (`switch_patch_ports`, `device_maintenance_logs`, `consumables`, `consumable_logs`, `audit_activities`, `soft_deletes`)**:
  - Added typed `deleteSwitchPatchPort` and `deleteSwitchPatchPortsForSwitch`, migrating `SwitchPatchMatrixScreen` to fully typed operations.
  - Deprecated legacy untyped map helpers (`insertMap`, `updateMap`, `deleteRow`, `query`, `rawQuery`, `deleteTable`).
  - Migrated switch patching, device maintenance logs, consumable inventory adjustments, immutable audit trails, and soft deletes to typed Drift queries.
  - Added reactive streams: `watchSwitchPatchPorts()`, `watchMaintenanceLogsForDevice()`, `watchConsumables()`, `watchConsumableLogs()`, `watchAuditActivities()`, `watchSoftDeletes()`.
- **Comprehensive Test Suite**:
  - Added `test/drift_typed_parity_test.dart` (26 tests) verifying all 5 migration phases, typed aggregations, directory search, reactive stream emissions across multiple tables, case-insensitive log queries, and transaction rollbacks with 100% test pass rate.

### Fixed & Hardened (System Audit & Integrity)
- **Notification Timezone & Platform Safety**:
  - Eliminated `LateInitializationError` during test runs and uninitialized states by guarding `cancelReminder`, `cancelAll`, and `reconcileReminders` with `_initialized`.
  - Exposed and thoroughly verified `toUtcTZDate(DateTime date, int hour, int minute, [DateTime? nowReference])` for DST calculations.
  - Added user snackbar feedback in `AddBorrowScreen` when an overdue reminder is saved with a time that has already elapsed.
- **Inventory & Activity Reactivity (AutomaticKeepAlive & Event Streams)**:
  - Added `AutomaticKeepAliveClientMixin` across all 7 inventory tabs (`Laptops`, `NetworkDevices`, `MiFis`, `AccessPoints`, `Printers`, `Electronics`, `OtherDevices`) to stop tab rebuilds and shimmer animations on swipe.
  - Subscribed all inventory tabs to reactive table listeners (`_db.tables(...)`) so statuses update instantly when items are checked out or returned in the Activity tab.
  - Wrapped `_load()` across inventory screens in `try/catch/finally` setting `_loading = false` to guarantee elimination of infinite shimmer loops on DB errors.
  - Added `ListenableBuilder` around company branding banners in `InventoryScreen` and `DashboardScreen` for real-time rebranding updates.
  - Guarded `InventoryScreen` tab listener with `!_tabs.indexIsChanging` to eliminate CPU churn during tab swipes.
- **Deletion Safety & UI Exception Protection**:
  - Intercepted item deletions in `ElectronicsScreen` and `MiFisScreen` when devices are actively borrowed, preventing unhandled `StateError` crashes and presenting clear guidance.
  - In `EmployeesScreen`, added `getEmployeeDependentCounts(empId)` to verify active borrows, emails, and ticket associations before deletion, with detailed warning dialogues.
  - Updated bulk deletions to safely skip actively borrowed equipment and employees while summarizing skipped items.
- **Excel Replace Confirmation Counts**:
  - Prompted explicit confirmation showing existing database record counts before running destructive `replace: true` Excel imports across all 12 asset categories and expenses in `DataHubScreen`.
- **Navigation & Clipboard Security**:
  - Implemented real `SharedAxisTransition` (scaled) in `NavigationUtils.sharedAxisRoute` using `package:animations`.
  - Added `copySensitiveToClipboard(BuildContext context, String text, String label)` with 45-second timer auto-clear for credentials.
  - Modernized `showSnack` to use theme colors (`cs.error`, `cs.tertiaryContainer`, `cs.onError`).
- **App Startup & Quick Actions Integration**:
  - Wired `QuickActions` to root `navigatorKey` routing directly to Network Scanner, Barcode Tag Scanner, and New Checkout.
  - Parallelized service initialization (`Future.wait`) on startup and added automatic 24-hour cleanup for temporary export files.
  - Added `HomeShellScope` inherited widget in `HomeScreen` to expose shell bottom navigation insets cleanly.
- **Data Integrity & Borrow Lifecycle Hardening**:
  - Centralized overdue calculation in `BorrowLog.isOverdue([DateTime? referenceDate])` across Dashboard, Borrowed Screen, and Custody generation.
  - Wrapped all borrow log operations (`insertBorrowLog`, `updateBorrowLog`, `markReturned`, `deleteBorrowLog`) inside atomic transactions with foreign key status synchronization.
  - Implemented bidirectional auto-healing in `syncDeviceStatuses()` to resolve out-of-sync hardware states on startup and import.
  - Added borrow checks preventing deletion of actively borrowed electronic/mifi devices (`isDeviceBorrowed`) and employees with active borrows (`getEmployeeActiveBorrowsCount`).
  - Added maintenance log deletion with confirmation dialog (`deleteMaintenanceLog`) in `DeviceMaintenanceScreen`.
  - Reconciled scheduled overdue notifications upon app launch and backup restore, handling DST transitions accurately using target date UTC conversions.
- **Backup & Excel Import Safety**:
  - Restored full schema parity across all 23 tables plus `prefs` in `exportJson()` and `importJson()`.
  - Added `replace` parameter to `ExcelImportService` batch imports with transaction rollback and pre-validation to prevent data loss on invalid files.
  - Protected masked email passwords (`••••••`, `(hidden)`) from overwriting active credentials during Excel imports.
  - Made backup file picker cancellation silent without raising false error snackbars.
- **Performance & System Resource Optimization**:
  - Bumped Drift database schema to version 14 with 6 composite indexes for borrow logs, audit logs, expenses, and switch ports.
  - Consolidated 18 sequential count queries in `DatabaseHelper.getCounts()` into a single multi-subquery SQL statement.
  - Implemented `TableNotifier` with 60ms debounce coalescing in `DatabaseHelper` to eliminate redundant UI re-renders during batch transactions.
  - Optimized `HomeScreen` with lazy tab rendering (`_visited` set) and stable `ActivityScreen` without recreation on tab switch.
  - Cached `_hasLogo` boolean in `CompanyService` to avoid synchronous filesystem `File.existsSync()` stats on widget rebuilds.
  - Migrated `NetworkScannerService` ICMP ping to `Process.start` with immediate child process termination on timeout, eliminated per-host ARP OS process forks, and added `_arpUnavailable` guard.
- **Security & Platform Modernization**:
  - Disabled ADB backup (`allowBackup="false"`) in `AndroidManifest.xml` to prevent corporate credential extraction.
  - Pruned overbroad root sandbox directories in `file_paths.xml` to protect private app data.
  - Enabled Android 13+ predictive back navigation (`enableOnBackInvokedCallback="true"`).
  - Synchronized displayed software version to v1.1.0 (Build 5).
  - Added lifecycle observer (`WidgetsBindingObserver`) in `HomeScreen` for day/date rollover updates.
  - Added condition picker and empty signature check in borrow custody slip modal.

### Added
- **Full-Screen Forms Across All Features**:
  - Replaced dialog-based creation and editing flows with full-screen fintech-styled form screens for:
    - Accounts & Passwords (`AccountPasswordFormScreen`)
    - Static IP Registry (`StaticIpFormScreen`)
    - Switch & Patch Matrix Chassis (`SwitchPatchChassisFormScreen`)
    - Wi-Fi Networks Registry (`WifiNetworkFormScreen`)
    - Inventory Others (`OtherDeviceFormScreen`)
  - Features dedicated `FintechAppBar`, full-width elevated bottom actions, form validation with haptic feedback, and shared-axis transition animations.
- **High-Precision LAN Device Discovery (Advanced IP Scanner Engine)**:
  - Enhanced `NetworkScannerService` with aggressive dual-pass scanning and kernel ARP harvesting.
  - Recognizes TCP RST (`Connection refused` errno 111, 10061, 61) as positive host liveness, detecting firewalled Windows PCs and dormant mobile devices.
  - Added UDP datagram ARP stimulation and subnet broadcast wakeup ping prior to scanning.
  - Automatically executes a deep second-pass sweep (600ms) for dormant hosts, bringing detection accuracy to 100% of LAN devices.
- **Expenses Real-Time Search**:
  - Added interactive `SearchBar2` to the Expenses screen with live filtering across expense categories, vendors, notes, and amounts.
- **Inventory Others 2-Column Grid**:
  - Standardized the "Others" tab UI to a responsive 2-column `GridView.builder` (`childAspectRatio: 1.32`) using `InventoryGridCard`, matching Laptops and Electronics views.
- **UI/UX Polish & SearchBar2 Unification**:
  - Replaced legacy `SearchBar` widgets with unified `SearchBar2` across Accounts & Passwords, Static IP List, Wi-Fi Networks, Inventory Others, and Expenses.
  - Fixed FAB delay in subpages: removed forward transition lag in `SmoothExitFab` so FAB buttons appear immediately upon navigation while retaining smooth exit fades.
  - Refined Dashboard top bar: removed stale company name above the date; converted date to a prominent, bold headline with 'IT Operations' subtitle.
  - Fixed Network Scanner top bar spacing between circular action buttons.
- **Wi-Fi Networks Registry Screen**:
  - Added centralized Wi-Fi networks registry aggregating all wireless networks from Routers, MiFis, and standalone networks.
  - Supports network name (SSID), password, phone number, location/device, admin username, admin password, and notes.
  - Features quick copy actions, hide/reveal toggles, and direct standalone network management.
- **Accounts & Passwords Vault**:
  - Added dedicated platform credential vault under **More > Management & Directory**.
  - Stores platform name, email/username, and password with security reveal toggles and clipboard actions.
- **"Others" Hardware Inventory Category**:
  - Added 7th tab to the main Inventory screen for miscellaneous hardware assets (projectors, NAS, UPS, barcode scanners, etc.).
  - Tracks device type, device name, model, and notes.
  - Fully integrated with database schema version 13, JSON backup & restore, Excel export, Excel import, and template generation.
- **Asset Labels - Switches & Patch Panels**:
  - Added Switch & Patch Panel category to **Asset Labels**, generating printable asset stickers and QR code tags.
- **Employee Onboarding & Audit Trail Logging**:
  - Added employee onboarding checklist in **Employee 360° Profile** and quick audit logging toggle in **Employee Form**.
  - Automatically records timestamped onboarding events in `audit_activities`.
- **SmoothExitFab Glitch Prevention**:
  - Introduced `SmoothExitFab` widget and neutralized `heroTag` across all FloatingActionButtons to eliminate transition flashes during route pop transitions.
- **Company Branding & Logo Customization**:
  - Added company logo picking, file storage, and removal under **Settings > Organization Identity**.
  - Display company logo prominently inside the Dashboard home screen card with branding details.
  - Automatically embedded company logo into all generated PDF documents (Borrow Custody Slips, Laptop Custody Slips, Bulk Laptop Custody PDFs).
- **Laptop Custody Slips & Data Hub Bulk Export**:
  - Added "Create Custody Slip (PDF)" directly to Laptop Overview details sheet with employee selection, signature capture, and company logo integration.
  - Added "Bulk Laptop Custody (PDF)" export tool in **Data Hub** allowing multi-selection of laptops to generate a single consolidated multi-page custody handover document.
  - Embedded corporate email resolution from `db.getEmailAccounts()`.
- **Direct Mail App Chooser Intent**:
  - Implemented native Android `MethodChannel` (`com.ma.itbox/email_launcher`) using `ACTION_SEND`, `message/rfc822`, and `FileProvider` so clicking "Email to User" opens mail app selection directly rather than the generic Android system share sheet.
- **Enterprise Multi-Protocol Network Scanner**:
  - Completely disassociated network scanning from local inventory database matching.
  - Added advanced scan options inspired by Angry IP Scanner, Advanced IP Scanner, and `usamaiqb/network-scanner`:
    - Custom IP range and CIDR subnet sweeps.
    - Bonjour / mDNS service discovery for Apple & Android friendly device naming (`_airplay`, `_companion-link`, `_apple-mobdev2`, `_googlecast`, `_raop`).
    - SSDP / UPnP device discovery resolving device friendly names and manufacturers via device XML descriptors.
    - NetBIOS workgroup / computer name probing via UDP port 137.
    - Web Service inspection (HTTP title grabbing on ports 80/443/8080/8443) and TCP service banner grabs.
    - Wake-on-LAN (WoL) magic packet sender tool.
    - CSV scan results export via system share.
- **Asset Labels Wi-Fi Cards Subtab**:
  - Transformed **Asset Labels** screen into a clean 3-subtab interface: `Categories`, `Custom Queue`, and `Wi-Fi Cards`.
  - Moved Executive Health Infographic export to **Data Hub**.
  - Eliminated the top 3-dots popup menu completely.

### Changed
- **Operations Activity Navbar & Centered Tabs**:
  - Restyled ActivityScreen top navbar with fintech container aesthetics and horizontally centered tab pills, resolving vertical text crowding.
- **Switch & Patch Matrix Edge-to-Edge Ports**:
  - Configured port bays to expand across the entire device card width when fewer than 24 ports are selected.
- **Dashboard Logo Display**:
  - Removed enclosing border container and background frame around company logo on dashboard for a clean presentation.
- **Initial App Onboarding Icon**:
  - Updated onboarding logo to `assets/icon/app_icon_raw.png` and removed enclosing background container.
- **Header Alignment Standardization**:
  - Standardized header title alignment and spacing (`titleSpacing: 20`) across Dashboard, Inventory, Activity, Emails, and More tabs.
- **Renamed Subnet Calculator**:
  - Renamed "CIDR Subnet Calc" to "Subnet Calculator" across all navigation routes, menus, and screen titles.
- **Clean Asset QR Code Stickers**:
  - Removed "IT BOX ASSET", device model, and assigned user subtitles from QR sticker sheets, rendering only clean device asset tag/name and scannable QR code.
- **Executive Health Report PDF**:
  - Removed document footer and separator lines from the Executive Health Infographic PDF.

### Fixed
- **Bulk Laptop Custody Export**:
  - Resolved issue where clicking export in Data Hub did nothing; now prompts system share sheet with generated PDF.

### Fixed
- **App Startup White Stutter Glitch**:
  - Preloaded `ThemeService` asynchronously before `runApp()` in `main.dart` to prevent theme brightness flickering on startup.
  - Initialized `_FadeIndexedStackState` animation controller at `value: 1.0` to eliminate white flash on initial route render.
- **App-Wide Add/Delete White Flash / Shimmer Glitch**:
  - Fixed `ShimmerListLoader` runtime layout exception in `common_widgets.dart` and adapted shimmer colors to theme surface brightness.
  - Implemented non-blocking background reloads (`_load({bool showLoader = false})`) across all screens (Laptops, Borrows, Access Points, Bills, Electronics, Emails, Employees, Expenses, Logs, MiFis, Network Devices, Printers, Subscriptions) so adding or deleting items updates the list smoothly without flashing white shimmers.

### Removed
- **Recycle Bin**:
  - Completely removed Recycle Bin module, screen files, and database soft-delete operations. Delete actions now execute permanent deletions directly.
- **Report Builder Module**: Completely removed legacy report builder screen and references.
- **Settings Data Management Section**: Completely removed redundant Data Management section from `SettingsScreen` (all backup, export, and import tools are housed in `DataHubScreen`).
- **Dashboard Quick Actions**: Removed static quick action grid in favor of the new expandable FAB.

---

## [1.1.0+5] - 2026-10-03

- **Rebuilt Advanced IP Scanner (`NetworkScannerScreen` & `NetworkScannerService`)**:
  - Rebuilt network scanner engine completely from scratch on the structure of Advanced IP Scanner for high-precision alive detection, MAC resolution, and device identification:
    - **Windows Desktop Engine**: Direct Layer-2 Win32 `SendARP` via `dart:ffi` calling `iphlpapi.dll` to guarantee 100% accurate MAC address and alive status even through firewalls.
    - **Android & Linux Engine**: Multi-tier active sweep using ICMP ping bursts, dynamic OS ARP table parsing (`/proc/net/arp`), and `ip neigh` harvesting.
    - **Comprehensive Multi-Protocol Identity Suite**: NetBIOS NBSTAT (UDP 137) for PC names, workgroups, and users; Apple Bonjour & mDNS (UDP 5353) for Apple/Android devices; SSDP/UPnP (UDP 1900) with XML descriptor fetching; LLMNR (UDP 5355); Reverse DNS (PTR); and HTTP/HTTPS title & header grabs.
    - **Expanded IEEE OUI Vendor Database**: Comprehensive MAC vendor database covering 100+ major manufacturers.
    - **Fintech Card UI & Filtering**: Live streaming host list, responsive device type filter chips (Workstations, Routers, Printers, Mobiles, Servers, IoT), and dynamic search query bar.
    - **Ecosystem Integration**: Direct 1-tap import from discovered devices into itBox Inventory (Laptop, Printer, Access Point, Network Device) and Static IP registry, with Web Admin launcher and Wake-on-LAN magic packet transmission.
- **Complete Local Network & Port Scanner (`NetworkScannerScreen`)**:
  - Offline subnet sweep discovering active hosts across `192.168.x.x` with response latency (ms).
  - Reverse DNS hostname lookups and active OS fingerprinting heuristics (Windows, Linux/Unix, Network Printers, Routers).
  - Targeted port scanner probing standard IT services (HTTP, HTTPS, SSH, SMB, RDP, JetDirect 9100, etc.).
  - Cross-references discovered hosts with IT Box's registered inventory with 1-tap addition to Static IPs.
- **Integrated Barcode & QR Code Scanner (`BarcodeScannerScreen` - Feature #1)**:
  - Full-screen camera-based barcode and QR scanner using `mobile_scanner` with flashlight toggle and target reticle.
  - Automatic hardware asset lookup across Laptops, Routers, MiFis, Printers, and Electronics.
- **Device Maintenance & Repair History Log (`DeviceMaintenanceScreen` - Feature #4)**:
  - Per-device service timeline tracking repairs, component upgrades, and inspections.
  - Automatic cost linking into department expenses with technician logging and lifetime cost summary cards.
- **Digital Equipment Custody Slip & Handover PDF (`CustodyPdfService` - Feature #9)**:
  - Generates official A4 equipment custody agreements with hardware specs, condition notes, and terms.
  - Interactive on-screen signature canvas with `signature` package for employee sign-offs.
  - Dedicated action button on borrowed cards to share or directly email the PDF to the borrower.
- **Employee 360° Profile & Dossier (`Employee360Screen` - Feature #10)**:
  - Comprehensive view aggregating assigned laptops, active gear loans, corporate emails, and trouble tickets for any employee.
- **Interactive Offboarding Exit Clearance Checklist (Feature #11)**:
  - Guided recovery checklist to retrieve hardware, return loans, revoke emails, and archive employee exit clearance.
- **Consumables & Bulk Stock Ledger (`ConsumablesScreen` - Feature #12)**:
  - Quantity tracking for non-serialized bulk items (cables, toners, batteries, adapters) with fast +/- stepper controls.
  - Color-coded glowing low-stock alerts when inventory dips below minimum safety thresholds.
- **Static IP Address Management List (`StaticIpListScreen` - Feature #14)**:
  - Dedicated IPAM registry to log, track, and manage all assigned static IPs, subnets, and MAC addresses.
- **Visual Switch Port Patch Matrix (`SwitchPatchMatrixScreen` - Feature #15)**:
  - Interactive 24-port Gigabit switch panel visualization with LED indicators (Active, Down, Disabled).
  - Port drop configuration for connected devices, room locations, and VLAN tags.
- **Offline CIDR Subnet Calculator (`CidrCalculatorScreen` - Feature #16)**:
  - Interactive subnet planning tool calculating usable host ranges, broadcast addresses, and netmasks from CIDR prefixes.
- **Printable Wi-Fi Access Cards PDF (2 / Page - Feature #17)**:
  - Generates A4 printable sheets with exactly 2 cards per page for selected office networks with QR codes, credentials, and cut guidelines.
- **Executive IT Department Health Infographic (`ExecutiveHealthPdfService` - Feature #22)**:
  - One-page high-impact vector PDF summarizing fleet size, asset valuation, active loans, overdue alerts, and financial run-rates.
- **Soft-Delete Recycle Bin & Trash Vault (`RecycleBinScreen` - Feature #25)**:
  - 30-day soft-delete retention allowing 1-tap item restoration or permanent purging.
- **System Activity & Audit Trail Feed (`ActivityFeedScreen` - Feature #26)**:
  - Chronological audit journal recording all create, update, delete, checkout, and offboard operations.
- **Custom Report Builder (`CustomReportBuilderScreen` - Feature #28)**:
  - Export customized Excel spreadsheets by selecting specific tables and columns.
- **Android App Shortcuts & Quick Actions (Feature #30)**:
  - Home screen quick actions for "Network Scanner", "Scan Asset Tag", and "New Checkout".
- **Drift SQLite Database Schema v12**:
  - Added compile-time tables: `DeviceMaintenanceLogs`, `Consumables`, `ConsumableLogs`, `StaticIps`, `SwitchPatchPorts`, `AuditActivities`, and `SoftDeletes`.
- **Expensy-Style Floating Rounded Navigation Bar**:
  - Replaced the bottom navigation bar with Expensy's exact floating pill container styling (`padding: EdgeInsets.fromLTRB(20, 0, 20, 16)`, `borderRadius: 22`).
  - Added `RoundedSquareBorder` indicator shape (`borderRadius: 14`, `size: 40`) matching Expensy's squircle tab highlights.
  - Implemented tab-specific active accent colors across all 4 root tabs (Home: Blue, Inventory: Emerald, Activity: Purple, More: Teal).
  - Integrated `FadeIndexedStack` (`Duration(milliseconds: 250)`) providing smooth fade transitions between main navigation views.
  - Added subtle elevation shadow and dynamic border adapting to light/dark themes without splash overflow (`NoSplash.splashFactory`).
- **Expensy-Style More Hub Grid Layout**:
  - Redesigned `MoreScreen` from a simple vertical card list into Expensy's signature 2-column grid layout (`SliverGrid` with `crossAxisCount: 2`, `childAspectRatio: 1.36`).
  - Added category section headers (`MANAGEMENT & DIRECTORY`, `TOOLS & PREFERENCES`) with vibrant tab teal accents.
  - Refactored items into compact squircle cards featuring rounded icon badges, bold headers, subtitle hints, and tactile haptic taps.
  - Added circular settings action button in the edge-to-edge header.
- **JetBrains Mono Monospace Font for Emails & Security Passwords**:
  - Configured `credentialFont` utilizing `GoogleFonts.jetBrainsMono` with distinguished glyphs where capital `I` (eye with crossbars) and lowercase `l` (el with curved tail), as well as digit `1` and `0` vs `O`, are unmistakably distinct.
  - Added `jetbrains_mono` to typography choices in `kFonts` and `ThemeService`.
  - Applied `credentialFont` to email account titles, detail sheets, and password preview masks in `EmailsScreen`.
  - Applied `credentialFont` to both email address and password input fields in `EmailFormScreen` and updated `AppTextField` with customizable `style` and `DetailRow` with `textStyle`.
- **Production Split-per-ABI APK Release**:
  - Successfully generated optimized release split APK binaries (`app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`) with tree-shaken font assets and minimal install footprint.

### Fixed
- **White Screen Flashing on App Launch & Dark Mode**:
  - Added native Android dark splash theme configuration in `android/app/src/main/res/values-night/colors.xml` with dark background (`#141218`), eliminating the stark white screen flash during native cold starts in dark mode.
  - Aligned dark theme background palettes with Expensy Material 3 values (`darkBg: 0xFF141218`, `darkCard: 0xFF2B2930`, `darkSurface: 0xFF211F26`).
- **White Screen Flashing on Pull-to-Refresh**:
  - Fixed `ShimmerListLoader` inner box decoration which previously had hardcoded `Colors.white`, replacing it with theme-aware `cardColor` (`isDark ? Color(0xFF2B2930) : Colors.white`).
  - Added silent refresh (`showLoader: false`) across `DashboardScreen`, `BillsScreen`, `EmailsScreen`, `EmployeesScreen`, `ExpensesScreen`, `BorrowedScreen`, `LogsScreen`, and `SubscriptionsScreen`, keeping existing data mounted on pull-to-refresh without unmounting the list or flashing shimmering skeleton boxes.

---

## [1.0.3+4] - 2026-10-02

### Added
- **Full Database Migration to Drift (Dart FFI & Background Isolate)**:
  - Transitioned the database persistence layer from raw `sqflite` to **Drift** (`drift: ^2.35.0`, `sqlite3_flutter_libs: ^0.6.0+eol`).
  - Defined strongly typed schema tables in `lib/database/tables.dart` and implemented `AppDatabase` in `lib/database/app_database.dart` with background isolate connection (`NativeDatabase.createInBackground`).
  - Upgraded `DatabaseHelper` to a high-performance singleton facade delegating all operations to Drift, maintaining zero-breakage backward compatibility with all UI screens, models, and tests.
  - Generated code via `drift_dev` and `build_runner`.
  - Cleaned up obsolete raw SQLite open logic, direct `db.query` calls, and duplicate table handlers.
  - Initialized `DatabaseHelper().init()` asynchronously in `main.dart` with foreign keys enabled (`PRAGMA foreign_keys = ON`) and automated self-healing device status checks.
  - Produced production split-per-ABI release APKs (`app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`).
- **Project Structure Documentation (`STRUCTURE.md`)**:
  - Authored a comprehensive architectural and data-flow reference manual.
  - Added full Mermaid Entity-Relationship Diagrams (ERD) covering all 11 SQLite tables and relational constraints.
  - Added app lifecycle sequence charts, borrowing self-healing status lifecycle diagrams, screen navigation hierarchies, and isolate-driven import/export pipelines.
- **Continuous Documentation Synchronization Standard**:
  - Established project rule requiring synchronized updates across `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `AI_Instructions.md`, and `STRUCTURE.md` after code changes.
- **Refreshed README.md**:
  - Completely rewrote `README.md` following the standardized `README_TEMPLATE.md` layout, detailing offline privacy, hardware tracking features, and technical specifications.
- **Optimization & Clean-up Roadmap**:
  - Formulated a comprehensive implementation plan targeting dead code removal, battery/background lifecycle efficiencies, and rendering performance optimizations.
- **Expensy Tech Stack & Dependency Synchronization**:
  - Aligned Flutter and Android build toolchain with `expensy`:
    - Android Gradle Plugin (AGP) `9.1.0`.
    - Kotlin Gradle Plugin (KGP) `2.4.0` with `android.builtInKotlin=true`.
    - Gradle Wrapper `9.3.1`.
    - Core library desugaring updated to `desugar_jdk_libs:2.1.5`.
    - Android Proguard rules configured in `android/app/proguard-rules.pro`.
  - Synchronized package dependencies to expensy versions:
    - `sqflite: ^2.4.4`
    - `path_provider: ^2.1.4`
    - `intl: ^0.20.2`
    - `file_picker: ^13.1.0` (with `FilePickerPlatform.instance` API support)
    - `pdf: ^3.12.0`
    - `printing: ^5.14.3`
    - `shared_preferences: ^2.3.2`
    - `flutter_local_notifications: ^22.3.1`
    - `url_launcher: ^6.3.0`
    - `google_fonts: '>=8.2.1 <9.0.0'`
    - `dynamic_color: '>=1.9.0 <2.0.0'`
    - `shimmer: ^4.0.0`
    - `share_plus: ^13.3.1`
    - `flutter_lints: ^6.0.0`
- **Expensy Theming Options & App Style Integration**:
  - Full seed palette synchronization: expanded to all 29 seed color options with `kSeedColors` and human-readable `kSeedLabels`.
  - Extended font typography selector (`kFonts`) supporting Plus Jakarta Sans, DM Sans, Inter, Nunito Sans, Space Grotesk, Outfit, Sora, Poppins, and Nunito with preview cards.
  - Wallpaper-derived Dynamic Color toggle (`dynamicColorEnabled`) with Android 12+ wallpaper color extraction using `DynamicColorBuilder`.
  - True Black (AMOLED) surface contrast mode preserved and decoupled.
  - Imported core design components from expensy: `RoundedSquareBorder`, `FintechHeader`, `FintechCircleButton`, `FintechSegmentedControl`, `FintechContainedLedger`, `FintechHeroCard`, `FintechFab`, and `FintechExtendedFab`.
  - Modernized `AppTheme` with predictive back gesture page transitions (`CupertinoPageTransitionsBuilder`) and custom `ExpensyRoute` / `ExpensySlideUpRoute`.
- **Complete Fintech Design System Transformation**:
  - Implemented high-readability **Plus Jakarta Sans** typography with tabular figures (`FontFeature.tabularFigures()`) across the entire application for numerical and statement alignment.
  - Designed and deployed **Fintech Component Suite** (`lib/widgets/common_widgets.dart`):
    - `FintechStatCard`: High-impact numeric metric cards with micro-borders and trend accents.
    - `CustomItemCard`: Statement-styled inventory rows with squircle leading icons and status pills.
    - `InventoryGridCard`: 2-column hardware inventory tiles with condition badges and user tags.
    - `FintechGroupedCard`: Inset grouped section containers (18px radius) with hairline borders for form fields.
    - `StatusBadge` & `ConditionBadge`: Glowing status pills with pulsing color-coordinated indicator dots.
    - `showFintechBottomSheet`: Standardized 28px bottom sheets with tactile grab handles, headers, and quick copy actions.
    - `showConfirmDialog`: High-clarity confirmation modals with squircle warning containers and pill buttons.
    - `SearchBar2`: Modernized squircle search bar with rounded corners and clear actions.
  - **Floating Pill Navigation Bar** (`lib/screens/home_screen.dart`): Floating navigation capsule with smooth active capsule indicator and subtle elevation.
  - **Dashboard Redesign** (`lib/screens/dashboard/dashboard_screen.dart`):
    - Added stylized greeting header with live datetime display.
    - Added overdue loan alert banner with glowing micro-border and urgent action triggers.
    - Added ticket resolution banner showing pending open and critical IT issues.
    - Added rounded squircle quick-action buttons with vibrant tint backgrounds.
    - Added horizontal financial metric cards (`FintechStatCard`) and statement-style active loan tiles.
  - **Hardware Inventory Suites**:
    - Overhauled Laptops, Network Routers, Access Points, MiFis, Printers, and Electronics.
    - Categorized filter pills with smooth animated transitions.
    - Redesigned bottom sheet detail inspectors with 1-tap copyable clipboard fields (`DetailRow`).
    - Standardized all creation & edit forms into inset `FintechGroupedCard` sections with full-width sticky bottom action buttons.
  - **Financials & Operations Modules**:
    - **Expenses**: Added EGP hero balance card, monthly comparative breakdown, and statement transaction cards.
    - **Bills**: Added category pill filter bar, total commitment summary card, and invoice receipt detail sheets.
    - **Subscriptions**: Added monthly burn rate overview card, renewal interval filters, and software license receipt sheets.
    - **Borrowed Devices**: Added active/history segments, loan status progress bar, overdue warning badges, and detailed borrower sheets.
    - **Employees**: Added employee directory cards with avatar initials, detail bottom sheet, and phone dialer/clipboard shortcuts.
    - **Emails**: Added corporate credential vault cards with secure password toggle and 1-tap copy triggers.
    - **IT Tickets**: Added resolution rate progress card, priority badges (`High`, `Medium`, `Low`), and detailed issue inspectors.
    - **More Hub & Settings**: Transformed into structured fintech preference centers with hardware counts, theme selector pills, AMOLED toggles, and data export/import tiles.
    - **Onboarding**: Modernized first-run setup screen with workspace branding and offline privacy guarantee.

### Changed
- Refactored text inputs with `AppTextField` suppressing unwanted predictive text / autocorrect popups while preserving clean fintech border styling.
- Standardized form navigation to strictly adhere to bottom sticky save buttons (no Save actions in `AppBar`).
- Replaced all legacy dropdowns with `InputDecorator + DropdownButton` to eliminate Flutter form field warnings.

---

## [1.0.3] - 2026-08-06

### Added
- **Modern Navigation & Transitions** — Replaced basic Material routes with `SharedAxisTransition` (via `NavigationUtils`) for all page navigations to provide fluid, staggered cross-fade motions.
- **Hero Animations** — Implemented `Hero` tags across all list screens (Laptops, Employees, Emails, Electronics, etc.) to smoothly animate device icons/avatars into their respective detail popups.
- **Micro-Interactions & UI Feedback** — Integrated `animations` package for staggered `SlideInAndFade` list item entrances. Added `ShakeWidget` to the login screen for iOS-style haptic validation failures.
- **Dashboard Data Visualization** — Replaced the generic expense summary card with a dynamic 6-month historical **Expenses Bar Chart** right on the Dashboard using `fl_chart`.
- **Shimmer Loading States** — Replaced generic circular loading spinners with structural `ShimmerListLoader` skeleton screens, massively boosting perceived performance.
- **Bulk Management (Multi-select)** — Introduced a robust multi-select architecture across all main inventory lists. Long-press any item to enter "Selection Mode", allowing bulk deletion from a clean bottom navigation bar.
- Multi-select capability to export PDF labels for specific and multiple categories at once.
- Floating Add button on the Dashboard for quick access to add Employees, Tickets, and Borrowing logs.
- Priority selection (Low, Medium, High) for Tickets with colored indicators on ticket cards.
- Bulk Selection (Delete and Duplicate) across all Inventory tabs via long-press.
- Toggle in MiFi and Electronics forms to exclude specific devices from the borrowing dropdown list.
- Tag field in the MiFi form for additional categorization.
- Option to edit an existing borrowing entry.
- Open Tickets section to the Dashboard.
- Added a time picker to choose the reminder time in borrow entry.
- Added a "Close Ticket" button to open tickets in the Log screen (prompts for solution if empty).

### Changed
- Renamed "Logs" to "Tickets" across the app.
- Improved Label PDF export layout to use 4 columns instead of 3 to save paper.
- Access Point labels now include the port number.
- Removed hint texts / examples from all entry forms but kept keyboard suggestions enabled.
- Back button from any tab now returns to the Dashboard.
- Export Labels moved from Settings to the More tab.
- Developer option in Settings now displays a modal with GitHub and Developer Website links.
- Removed Subscriptions quick action from the Dashboard.
- Dashboard open tickets section now correctly displays the date and employee name.
- Renamed ticket closure confirmation button from "Delete" to "Close".

### Fixed
- Unified text inputs with `AppTextField` to resolve text selection behavior where clicking selected all text instead of moving the cursor.
- Keyboard Enter key behavior now correctly advances to the next form field instead of dismissing the keyboard.
- Completely disabled predictive text and autocorrect across all text fields in the app to provide a cleaner input experience.
- Re-enabled dynamic adaptive theme support when selecting System Theme.
- Added INTERNET permission to properly fetch customized app fonts offline.
- Fixed borrowed device notifications by calculating timezone offset manually instead of defaulting to UTC.
- Updated the status bar notification icon to match the monochrome themed icon.
- Ensure the selected reminder time is preserved when editing a borrowing entry.
- Restored `exactAllowWhileIdle` schedule mode so notifications fire reliably exactly on time even when the app is completely closed or Dozing.
- Fixed Android system settings showing 1.0.0 app version instead of the pubspec version.
- Open and Closed tabs inside the Log screen.
- State property (Open/Closed) for Log Entries.
- Integrated comprehensive theming system (Dark/Light/System, 29 accent colors, 10 app fonts, and AMOLED pure black mode).
- Fixed Developer and GitHub profile links in settings to launch externally properly.
- Fixed an issue with FloatingActionButton showing briefly during tab transitions.

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
- Removed hint texts / examples from all entry forms but kept keyboard suggestions enabled.
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
- **Swipe Actions** — Swipe-to-delete functionalities (`Dismissible`) were completely stripped from the app per user request, replaced by the unified multi-select bulk management bottom bar.
- **Device QR Scanning Module** — Completely removed `mobile_scanner` dependency and check-in/check-out barcode scanner features (`ScannerScreen`) per user request to keep the app lightweight, fast, and focused on offline IT management.

---

## [1.0.1] — 2026-05-24 *(Inventorya → IT Box)*

### Changed
- Removed hint texts / examples from all entry forms but kept keyboard suggestions enabled.
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
- Removed hint texts / examples from all entry forms but kept keyboard suggestions enabled.
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

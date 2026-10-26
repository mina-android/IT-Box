# IT Box — Verification & Fix Plan (Audit of 2026-10-26)

Full codebase verification against the enterprise-grade checklist (features working as intended, backup
restore completeness, dead code, UI reusability, theme compliance, code comments, no unnecessary
fallbacks). Every finding carries `file:line` evidence verified against source. **No code was changed —
this is a plan only.**

Baseline tooling results: `flutter analyze` → **No issues found**. 4 test files compile and pass
against the current API surface. 51 screens: all reachable. 16 model files: all used.

---

## 0. Verification Verdict Summary (mapped to the audit checklist)

| # | Checklist item | Verdict |
|---|----------------|---------|
| 1 | Every feature working as intended | ⚠️ Mostly, with **1 Critical Excel bug + 8 Major logic bugs** (Section 3) |
| 4 | Backup restores any attached file | ⚠️ All 23 DB tables covered **but** logo file, theme prefs, version checks missing (Section 2) |
| 5 | No dead/unused code | ❌ ~40 dead items found (Section 4) |
| 6 | Every UI element a reusable block | ⚠️ Core kit ~500 call sites is excellent, but 5 layers copy-pasted per-screen (Section 5) |
| 7 | UI follows selected theme properly | ❌ 13 light/dark surface hacks, 4 light-mode contrast bugs, hardcoded accents everywhere (Section 6) |
| 8 | `//` note on every function/block | ❌ ~10–15% function-level comment coverage overall (Section 7) |
| 9 | No unnecessary fallbacks/workarounds | ⚠️ No rot markers, but 11 silent migration catches, exception-based lookups, 1 missing re-sync (Section 8) |

---

## 1. RELEASE BLOCKERS (fix before any distribution)

### R1. Application ID is still the Flutter template — CRITICAL
- `android/app/build.gradle.kts:9` `namespace = "com.example.inventorya"`, `:24` `applicationId = "com.example.inventorya"`, with the Flutter TODO comments still present (`:23`).
- Docs (CLAUDE.md, CHANGELOG) claim `com.ma.itbox`. Package ID mismatch breaks any existing user upgrade path, Play Store identity, and FileProvider authority (`${applicationId}.fileprovider`).
- **Fix:** set `applicationId`/`namespace` to `com.ma.itbox` (verify against the previous Inventorya release signature so existing installs upgrade).

### R2. Release builds are signed with the debug key — CRITICAL
- `android/app/build.gradle.kts:35-37`: buildType release → `signingConfig = signingConfigs.getByName("debug")`, comment "Signing with the debug keys for now".
- **Fix:** add a `keystore.properties`-driven release signing config (keyAlias/keystore path/passwords outside version control), fallback to debug only behind a local flag.

### R3. README privacy claims contradict the manifest — MAJOR
- README: "no external network permissions are used", CLAUDE.md: "No INTERNET — no network calls".
- `AndroidManifest.xml` declares `INTERNET` (required by the network scanner — legitimate) plus `CAMERA`, `ACCESS_FINE_LOCATION`, etc., undocumented anywhere in user-facing docs.
- **Fix:** update README/CLAUDE.md privacy sections to accurately declare every permission and why it exists (scanner local network usage). Never misdescribe permissions — Play Store policy risk.

### R4. minSdk / Android-version story is inconsistent across docs
- README says "Android 8.0 (API 26)", "about 28 MB", and "minSdk 21"; CLAUDE.md says "Min SDK 31"; `pubspec.yaml` launcher config says `min_sdk_android: 31`; gradle uses `flutter.minSdkVersion` (default 24 today).
- **Fix:** pin `minSdk` explicitly in gradle, then align all 5 docs to the real value.

---

## 2. ITEM 4 — BACKUP / RESTORE (the "attached files" requirement)

**What already works (verified):** all 23 database tables exported AND restored in lockstep
(`database_helper.dart:1781–1805`); single-transaction atomic restore with rollback (`:1829–1856`);
PRAGMA column allowlist filtering (`:1838–1849`); post-restore `syncDeviceStatuses()` + reminder
reconciliation (`:1877–1879`); malformed JSON & cancelled-picker handling.

### B1. Company logo file is not backed up — HIGH
- `company_service.dart:12,22,44–50`: logo is a SharedPreferences path + an image file on disk. `exportJson` (`database_helper.dart:1807–1824`) contains neither.
- **Fix plan:** embed the logo as a base64 data string under `prefs` (e.g., `'company_logo'`) in `exportJson`; on `importJson`, write it back to the documents dir and repoint `company_logo_path`. Also expose an attachment-style slot so the expense subscription receipt images (if any on disk) follow the same pattern if introduced.

### B2. Theme preferences never backed up — HIGH
- `theme_service.dart:28–34`: themeMode, themeSeed, appFont, amoledSurfaces, dynamicColorEnabled. None in the backup `prefs` map (`database_helper.dart:1815–1817`).
- **Fix plan:** serialize all 5 keys inside the existing `prefs` map and restore each with schema-safe defaults.

### B3. Backup version is a hardcoded `8` and never validated — HIGH
- `database_helper.dart:1812` writes `'version': 8` while `app_database.dart:51` schemaVersion is **14**; `importJson` never reads the field.
- **Fix plan:** write current schemaVersion + app version + device platform; on import, refuse (with a clear dialog) backups from a newer incompatible schema, and warn on old backups with a "data will be upgraded" path.

### B4. Partial backup does a *mixed* restore that contradicts the UI promise — MEDIUM
- `database_helper.dart:1831`: tables absent from the JSON are skipped, not cleared; the confirm dialog says "This will replace ALL current data" (`data_hub_screen.dart:68`).
- Orphaned `borrow_logs` can survive referencing the replaced `employees`/`mifis`/`electronics` (no FK constraints exist — `tables.dart` declares no `references()`).
- **Fix plan:** either (a) verify all 23 required keys exist up front and reject the file as an invalid IT Box backup, or (b) make the dialog say exactly which tables will be replaced. Preferred: (a) + `PRAGMA foreign_key_check()` post-restore guard.

### B5. No strict restore validation — MEDIUM
- Empty `{}` JSON reports "Database restored successfully" (`data_hub_screen.dart:76`); row type checks only `is Map` (`:1842`); no checksum/digest.
- **Fix plan:** add (1) a SHA-256 checksum line in the export validated on import, (2) a required-tables manifest, (3) reject non-map root rows with a count in the summary, (4) after restore run `foreign_key_check` and surface the result.

### B6. Onboarding "Restore Backup" has no confirmation dialog — MEDIUM
- `onboarding_screen.dart:40–73` imports immediately on file pick, unlike Data Hub (`data_hub_screen.dart:64–72`). Combined with C-S1 below, an empty backup silently rewires branding.
- **Fix plan:** reuse `showConfirmDialog` before import; show restore summary (tables + row counts + company name found) from the parsed file *before* committing.

### B7. Data Hub mislabels plaintext JSON as "encrypted" — LOW
- `data_hub_screen.dart:906` vs `jsonEncode` plaintext (`database_helper.dart:1823`).
- **Fix plan:** either reword the copy or implement real protection (e.g., optional AES passphrase). If a passphrase is added, it must be *opt-in* and clearly branded, else reword to "snapshot".

### B8. Backup metadata too thin for enterprise migrations — LOW
- Only stale version int + timestamp (`database_helper.dart:1811–1818`).
- **Fix plan:** add schema version, app version, table manifest with row counts — enables both B3 and B5.

---

## 3. ITEM 1 — FEATURES: WORKING-AS-INTENDED DEFECTS

### C1. Excel import round-trip corrupts `expenses` and `log_entries` — **CRITICAL**
- Exporter `data_hub_screen.dart:104,108` (headers include leading `#`) + `:246–252, 268–274` (`_buildRows` prepends index `i`).
- Importers read **without** the `#` offset: `excel_import_service.dart:372–383` (`importExpenses`: row[0]=Date...) and `:554–589` (`importLogEntries`) — their own comments (`:357`) omit the `#`. Every other importer (laptops :118–129, mifis :193–204…) correctly offsets by 1.
- **Impact:** importing an IT Box export or the app's own blank template puts `date=today`, `item=<real date>`, `price=0`, `details=<real price>`; log rows shift identically. Verified by reading both sides.
- **Fix:** align both importers to the `#` column (offset 1) AND make the template generator emit the same layout; add a round-trip regression test (export → import → compare rows) for all 13 categories.

### C2. Excel "Replace" imports orphan active borrows and never re-sync statuses — **MAJOR**
- `excel_import_service.dart:70–104` `_executeBatchImport`: `deleteTable` at :94, no `syncDeviceStatuses()`/`reconcileReminders()` afterwards (unlike `importJson` at `database_helper.dart:1877–1879`); devices forced `'Available'` at :166, :203, :271; id reuse after delete repoints stale `borrow_logs.device_id` at unrelated devices.
- **Fix:** call `syncDeviceStatuses()` + `NotificationService().reconcileReminders(getBorrowLogs())` at the end of `_executeBatchImport`; in append mode keep device's real status; in replace mode warn when active borrow_logs reference imported tables.

### C3. Replace-mode email import silently drops masked accounts — **MAJOR**
- `excel_import_service.dart:400–443`: masked `'(hidden)'` rows are skipped, but `deleteTable('email_accounts')` still runs when *some* rows are valid (`:427` only guards the all-masked case).
- **Fix:** abort replace when any row is masked (message: "export masked passwords — append instead"), or merge-masked semantics. Document the invariant on both sides.

### C4. Employee rename/delete has no denormalized cascade — **MAJOR**
- `database_helper.dart:828–842` writes only `employees`. Snapshots exist in `laptops.user`, `email_accounts.employee_name/employee_id`, `borrow_logs.employee_name`, `log_entries.employee_name`. Employee 360 + laptop assignment join by name (`laptop_form_screen.dart:49–55`, `employee_360_screen.dart:43`); email FK dangles on delete (no FK in `tables.dart`).
- **Fix:** in `updateEmployee`, transactionally update the four denormalized name columns (`laptops`, `email_accounts`, `borrow_logs`, `log_entries`); on `deleteEmployee`, nullize `email_employee_id` + names or block deletion while dependents exist using existing `getEmployeeDependentCounts()`.

### C5. Open-ticket case rule inconsistency — **MAJOR (latent)**
- `database_helper.dart:1897,1923` filter `state='Open'` exactly; `dashboard_screen.dart:100` lowercases. Diverges under any non-'Open'-cased state (JSON restore from another install).
- **Fix:** normalize state at write time (single constant) + normalize in queries (`upper(state)`) so every counter agrees.

### C6. Static IP form accepts anything — **MAJOR**
- `static_ip_form_screen.dart:65–112`: no IP regex, no subnet/mask validation, no duplicate-IP check; writes straight to DB and logs an audit entry.
- **Fix:** validate IPv4 format + optional CIDR prefix; enforce unique active IP with a friendly conflict message; validate gateway/subnet consistency when provided.

### C7. Date normalizer silently rewrites unknown dates to today — **MAJOR**
- `excel_import_service.dart:519–552`: `substring(0,3)` RangeError on short month tokens; serial branch requires `serial > 1000`; unknown formats (e.g. `05/10/2026`, `Oct 15`) `return _today()` — silent data corruption feeding C1.
- **Fix:** fail loudly (row skipped + counted in errors) instead of defaulting to today; support `dd/MM/yyyy`, `MM/dd/yyyy` detection, 2-digit month tokens, serial ≤ 1000.

### C8. Wi-Fi QR strings not escaped — **MAJOR**
- `wifi_pdf_service.dart:23`: `'WIFI:S:$ssid;T:$security;P:$password;;'` — WIFI URI format requires escaping of `; : , \`.
- **Fix:** escape/encode the four special chars for SSID + password; add unit test with hostile SSID (`x;y:z,a`).

### C9. Shrinking a switch chassis leaves negative capacity — **MAJOR**
- `switch_patch_matrix_screen.dart:311` utilization `(active/total*100)` unclamped; `:588` LinearProgress value >1 (debug assertion); `:612–613` `'Available': totalPorts - _ports.length` can go negative; orphan ports beyond the shrunk range survive in `switch_patch_ports`.
- **Fix:** when editing a chassis to fewer ports, delete/migrate port rows beyond the new count inside a transaction; clamp utilization to 0–100%.

### C10. Reminder silently skipped when the time already passed today — **MINOR→MAJOR**
- `notification_service.dart:88–100` (`toUtcTZDate` → null when instant is past), `:57–58` `scheduleOverdueReminder` returns false with no surface, `reconcileReminders` (:122) ignores it. A due-today borrow with a 09:00 reminder created at 14:00 never notifies, no feedback.
- **Fix:** schedule immediately (1 minute out) when the ideal instant is missed, and show a confirm-time snackbar text when scheduling fails.

### C11._remaining small correctness fixes (batched)
| ID | Fix | Where |
|----|-----|-------|
| S2 | Reveal-password set keyed by list **index** — key by record id instead | `accounts_passwords_screen.dart:20,144,271–275` (model after wifi_networks' `Set<String>`) |
| S3 | "This Month" card zeroes when browsing other years — compute from full dataset or add a period label | `expenses_screen.dart` `_compute` |
| S4 | Return-date picker allows +1000 days future — clamp to today | `add_borrow_screen.dart:128` |
| S5/S6 | Windows: `LinuxInitializationSettings` passed on every platform → notifications dead on Windows dev builds; gate settings per-platform | `notification_service.dart:24–28` |
| S8 | Chassis id `DateTime.now().millisecondsSinceEpoch % 1000000` — dedupe against stored ids | `switch_patch_chassis_form_screen.dart:53–55` |
| S9 | No duplicate laptop-tag / duplicate-email validation | `laptop_form_screen.dart:74–90`, `email_form_screen.dart:296–304` |
| S11 | Label rows with 2+ `\n` silently drop lines 3..n — render all segments | `label_service.dart:58,91` |
| S12 | Quick-action events swallowed on cold start (navigatorKey null before runApp) — queue-and-flush pattern | `main.dart:55–69` |
| S7 | Scanner FFI/socket work runs on main isolate — move per-host sweep into `Isolate.run` batch like the Excel services | `network_scanner_service.dart` |

### Features verified clean (no defects)
Custody PDF flow, monthly financial PDF, JSON restore atomicity, borrow lifecycle core (`database_helper.dart:889–1005`), Drift migrations v14.

---

## 4. ITEM 5 — DEAD / UNUSED CODE (remove)

### D-1. Fully dead methods — delete
- `DatabaseHelper.updateMap` (`database_helper.dart:95`), `deleteRow` (`:110`), `getExpensesByMonth` (`:1199`), `updateConsumable` (`:1593`), `updateNetworkDeviceStatus` (`:665`, test-only).

### D-2. Dead widgets — delete
- `FintechHeader`, `FintechSegmentedControl` (+`FintechSegmentItem`), `FintechContainedLedger`, `FintechExtendedFab` — all definition-only in `fintech_components.dart` (`:5, 231, 389, 605`). (If Section 5 adopts `FintechSegmentedControl` as the real segmented-control implementation instead of deleting it, keep that one and delete only the others.)

### D-3. Dead-in-app API surface — decide and act
- 15+ `watchXxx()` streams never subscribed by any screen (watchNetworkDevices, watchPrinters, watchExpenses, watchBills, watchEmailAccounts, watchSubscriptions, watchAccessPoints, watchWifiNetworks, watchAccountPasswords, watchOtherDevices, watchMaintenanceLogsForDevice, watchStaticIps, watchSwitchPatchPorts, watchAuditActivities, watchSoftDeletes, watchConsumables, watchConsumableLogs).
- `getTotalExpenses/watchTotalExpenses/getTotalBills/watchTotalBills`, `getOpenLogEntries`, `getLogEntriesByMonth` — kept alive only by `drift_typed_parity_test.dart`.
- **Consumables feature** (`consumables` + `consumable_logs` tables + full CRUD) and **SoftDeletes API** (`soft_deletes` table + CRUD) have no UI and no screen.
- **Plan:** these are either (a) roadmap features being staged, or (b) dead weight. Decide per binary: if consumables/soft-deletes are planned (mention in CHANGELOG?), keep + note as "planned feature, UI pending" in docs; otherwise remove the CRUD surface and the parity tests that exercise it (`drift_typed_parity_test.dart:274–503, 596–710`, integrity parts). Enterprise default: remove until needed.

### D-4. Dependencies & assets — remove
- `printing: ^5.14.3` — zero imports (confirmed; `label_service.dart:10` even documents not using it), ~packaging savings.
- `cupertino_icons: ^2.0.0` — zero `CupertinoIcons` usages.
- `assets/icon/app_icon_mono.png` — declared `pubspec.yaml:60`, never referenced from Dart (only Android drawable separate). Verify no notification small-icon reference before removing.

### D-5. Legacy alias — remove
- `seedColour` "backward compatibility alias" (`app_theme.dart:107–110`) — zero callers.

### D-6. Dead doc references — update docs (Section 9)

---

## 5. ITEM 6 — UI REUSABILITY (make every element a reusable block)

Core kit is real and healthy (~500 call sites): `DetailRow` ×66, `FintechGroupedCard` ×79, `SectionLabel` ×65, `showSnack` ×136, `showConfirmDialog` ×35, `FintechAppBar` ×28 files, `FintechFab` ×22, `AppTextField` ×60, `SearchBar2` ×17, `showFintechBottomSheet` ×18, `EmptyState` ×20, `IconBox` (heavy).

### U1. Missing shared `SelectionBottomBar` — the biggest copy-paste
- Close-icon + "n selected" + delete row copy-pasted into **11 screens**: access_points:257, bills:378, electronics:267, emails:429, employees:493, expenses:635, laptops:251, logs:568, mifis:325, network_devices:243, other_devices:287.
- **Fix:** create `lib/widgets/selection_bottom_bar.dart` (`selectedCount`, `onDelete`, `onClose`); replace all 11 sites.

### U2. `CustomItemCard` never rolled out — 13 inline surface hacks instead
- `isDark ? AppColors.darkCard : Colors.white` card scaffolding repeated in emails:305, employees:353, logs:733/889, add_borrow:604/658/703, settings:504, onboarding:133, email_form:248, employee_form:86, log_form:283; `CustomItemCard` used in only 2 screens.
- **Fix:** adopt `CustomItemCard` (made theme-driven — see T2) in these screens; delete the 13 inline BoxDecorations.

### U3. Raw dropdowns bypass `FintechDropdown` (the documented hard rule)
- expenses_screen:361 (re-implements FintechDropdown's decoration with hardcoded colors :351,366), device_maintenance:67, static_ip_form:175, switch_patch_chassis_form:112/133, switch_patch_matrix:239.
- **Fix:** convert all 6 to `FintechDropdown<T>` (docs AI_Instructions rule "NO raw DropdownButton" is currently violated by its own codebase).

### U4. Four parallel "metric chip" implementations
- `FintechStatCard` (dashboard), `_StatMetricCard` (settings:481–537), `_statBadge` (switch_patch_matrix:656), `_badge` (wifi_networks:496), `_TicketMetricPill` (logs:983).
- **Fix:** one shared `MetricChip({icon,color,label,value})` in common_widgets; delete the 4 privates.

### U5. Segmented control duplication
- `FintechSegmentedControl` exists but unused; borrowed_screen re-invents it as `_BorrowSegmentCard:1000–1096`; inventory_screen builds its own chips (:96–121).
- **Fix:** either delete D-2 widgets or adopt: route borrowed + inventory + activity_screen through one segmented control.

### U6. Bottom-sheet builders bypass `showFintechBottomSheet`
- borrowed_screen:276, data_hub:796 (`_showTemplatesSheet` re-implements the drag handle), barcode_scanner:105, employee_360:74/165, network_scanner:95/461.
- **Fix:** route all 7 through `showFintechBottomSheet`.

### U7. Priority/status color mapping duplicated per screen
- logs_screen:348/714–718, activity_feed:97–104, borrowed_screen — instead of `AppColors.good/fair/poor`.

### U8. Per-screen `_xColor` accent functions (~12 files)
- bill_form:6/bills:8, email_form:8/emails:10, expense_form:7/expenses:11, log_form:9, mifi_form:6/mifis:8, sub form:7/screen:8 — plus a second duplicate category→color map inside bills_screen:163/420.
- **Fix:** centralize in `AppColors` (see T4).

### U9. `device_maintenance_screen.dart` ignores the component kit entirely
- Raw TextFormFields :63–84, raw DropdownButton :67, bare AlertDialog :60–156/164–178 — the only screen never modernized.
- **Fix:** full kit conversion (AppTextField, FintechDropdown, showConfirmDialog, SummaryRow).

---

## 6. ITEM 7 — THEME COMPLIANCE

### T1. Light-mode contrast bugs (user-visible) — fix first
- White/on-white hero cards: `FintechHeroCard` light gradient ends on `cs.surface` (`fintech_components.dart:508–511`) while 4 consumers hardcode white text: device_maintenance:209–213, cidr_calculator:122–126, network_scanner:496–523, employee_360:277–283.
- **Fix:** tie text color to the card's computed luminance or use `cs.onPrimaryContainer`-based tokens; verify in light mode.

### T2. Kill the 13 `isDark ? darkCard : Colors.white` surface hacks
- Breeds theme-blind surfaces (Material default greys) that ignore chosen seed colors and AMOLED.
- **Fix:** single source: `cardSurface(BuildContext)` → `colorScheme.surfaceContainerLow` (or AMOLED-aware token from app_theme.dart's tuned rail `#131318/#2B2B38/#282834/#2E2E3C`), used by `CustomItemCard`, `FintechActionButton` (fintech_components:717–722), settings `_StatMetricCard`.

### T3. `FintechDropdown` AMOLED detection is broken under dynamic color
- `fintech_dropdown.dart:38` compares `scaffoldBackgroundColor == Colors.black` string-equality; dynamic schemes never return literal black, so AMOLED popups can render with wrong surface.
- **Fix:** derive popup surface from `cs.surfaceContainerHighest`+`dropdownMenuTheme`; then delete the hack (pairs with U4/M).

### T4. Centralize accents in `AppColors`
- 15 hardcoded More-screen tile accents (more_screen:56–167), data_hub palette (:912–993), dashboard literals (0xFF6366F1 etc. — some literally the same value as existing AppColors constants, dashboard:273–863), logs_screen status colors (:928–970), settings `_StatMetricCard` args (:118–128), AP cyan `0xFF0891B2` (access_point files).
- **Fix:** move each into `AppColors` named constants; screens import only AppColors. Keeps status semantics central and seed-consistent.

### T5. SnackBar theme gap
- `snackBarTheme` lacks colors (`app_theme.dart`), so `showSnack` hardcodes green/red per call (common_widgets:598–614) and 4 raw snackbars exist (employee_360:139/230).
- **Fix:** add contentTextStyle/backgroundColor via tokens in theme; convert snackbars to read theme.

### T6. Plain `Colors.grey`/`Colors.white70` text (12+ sites)
- borrowed_screen:159,310,852,861; account_passwords:133,246; data_hub:409; log_form:157; employee_360:105,196; barcode_scanner:129; wifi_networks:217.
- **Fix:** `cs.onSurface.withValues(alpha: …)` or AMOLED solid tokens (`0xFF94A3B8`) as the theme docs prescribe.

### T7. Add missing component themes
- `dropdownMenuTheme` (enables T3), `chipTheme` (logs ChoiceChips), `popupMenuTheme`, `switchTheme`, `checkboxTheme`, `progressIndicatorTheme`, `textButtonTheme`/`filledButtonTheme` (currently ~every button hand-rolls `styleFrom`).
- **Fix:** extend `_base()` in `app_theme.dart`; then delete per-widget duplications progressively.

---

## 7. ITEM 8 — COMMENT COVERAGE

Aggregate function-level `//` coverage ≈ **10–15%**; ~40 files have zero comments. Files that pass: `excel_import_service.dart` (~85%), `network_scanner_service.dart` (~60%), `app_theme.dart`, `data_hub_screen.dart` (~50%).

### M1-comment. Comment sprint priorities (target: every function/class + non-trivial block)
| Priority | Files | Why |
|----------|-------|-----|
| P0 | `database_helper.dart` `syncDeviceStatuses()` (:1072), `exportJson`/`importJson` (:1807–1880), `init`/`watchCounts` | The most non-obvious business rules (status invariant, backup semantics) are undocumented; `syncDeviceStatuses` needs an invariant line: "status column must mirror open borrow_logs" |
| P0 | `main.dart` (0%), `add_borrow_screen.dart` (0%), `settings_screen.dart` (0%) | Entry point + core flow screens |
| P1 | `borrowed_screen.dart` (~5%), `logs_screen.dart` (~5%), `dashboard_screen.dart` (fns bare), `notification_service.dart` | Reminder semantics, revert logic |
| P1 | `network_scanner_service.dart` gaps: `_deduceDeviceType` (:1430), `_deduceOsGuess` (:1487), probe timeout constants (:451–915) | 90 lines of undocumented heuristics |
| P2 | All 22 `lib/models/*.dart`, all `*_form_screen.dart`, `tables.dart`, `theme_service.dart`, `company_service.dart`, `haptics.dart`, `common_widgets.dart` internals | Systematic families |

**Standard:** one `//` note per function/class/field-group stating intent (not narration); `///` doc comments on all DatabaseHelper API + singleton services. Est. effort: ~2 days across 40 files.

---

## 8. ITEM 9 — FALLBACKS / WORKAROUNDS

### F1. 11 silent `catch (_) {}` in database migrations — HIGH priority
- `app_database.dart:74,86,104,114,126,131,139,204,234,244,264` around raw-SQL migrations. With the `from < 14` + `addColIfMissing` self-healing (:237–254) these are redundant double-protection that can **hide a real migration failure** and boot a broken schema; the index-creation catch (:256–264) is pure noise (`IF NOT EXISTS` already).
- **Fix:** log failures (kDebugMode print or a lightweight logger); drop the index catch entirely.

### F2. Exception-based list lookups — replace idiom
- `add_borrow_screen.dart:80,97,101`, `laptop_form_screen.dart:52`, `email_form_screen.dart:46` — `firstWhere` without `orElse` in try/catch. Use `where(...).firstOrNull`.

### F3. Bulk-delete loops swallow per-item errors then claim success
- mifis_screen:119, employees_screen:116, electronics_screen:115 family — "3 deleted" snack can lie.
- **Fix:** count failures, report them ("3 deleted, 1 skipped — device on loan").

### F4. Excel import missing the post-op reconciliation (duplicated from C2)
- `_executeBatchImport` gap is both a correctness bug (C2) and a "workaround-by-omission" of the invariant importJson already implements.

### F5. Redundant double-init
- `notification_service.dart:89–91` re-initializes timezones inside `toUtcTZDate` though `init()` did it (both under catch-all).

### F6. Clean otherwise (verified, no action)
- No TODO/FIXME/HACK markers in Dart code; no sleeps-as-logic (2 legit SSDP listen windows); scanner probe catches are correct by design; `?? ''` usage is legitimate nullable-column defaulting; no redundant startup sync (`init` → `syncDeviceStatuses` once; only `importJson` repeats it, correctly).
- `@Deprecated` raw-SQL shims (`insertMap/updateMap/deleteRow/query/rawQuery/deleteTable`, `database_helper.dart:82–152`) are intentional and documented, but still the production path for backup/Excel (ties into D-1: prune the dead ones, keep `query/insertMap/deleteTable` until a typed exporter exists — note in docs that they are backup-only).

---

## 9. DOCUMENTATION DRIFT (fix as part of the hygiene pass)

The 5 doc files contradict each other and the code:
1. DB version: CLAUDE.md says v13 (`:76`) and v14 (`:20`, `:893`) in the same file; AI_Instructions says 14; README "[Schema v14]" is correct — **actual: 14, 23 tables**. AI_Instructions "23 tables" is correct; STRUCTURE's ERD lists only 15 tables and "All 15 Tables" — outdated.
2. CLAUDE.md hard-rule 12 mandates `NavigationUtils.sharedAxisRoute()`; but CHANGELOG 1.1.0 + AI_Instructions state routing is now standard `MaterialPageRoute` (Cupertino-style transitions). Code follows the latter → fix CLAUDE.md.
3. CLAUDE.md file map references `lib/widgets/app_drawer.dart` (doesn't exist), claims borrow_log has "return_date, signature" fields (it doesn't), and omits whole directories (`screens/maintenance/`, `screens/wifi_networks/`, `screens/accounts_passwords/`, `screens/others/`, `screens/barcode_scanner/`, `activity_screen.dart`, 4 newer models).
4. CLAUDE.md pitfalls: duplicated numbers (two 12s, two 13s, two 14s); Inventory tab count "7 sub-views" vs pitfall #8 "6 tabs" (actual: 7).
5. Backup format in CLAUDE.md shows 12 tables, version 4 — actual: 23 tables, `version: 8` + prefs + company_name (and pending Section 2 upgrades).
6. README privacy/offline claims vs INTERNET permission (R3); README Android version + size claims (R4).
7. `FintechHeader`/`FintechSegmentedControl`/`FintechContainedLedger`/`FintechExtendedFab` are presented as "components from Expensy design system" in AI_Instructions — 4 of them are dead (Section 4).

---

## 10. EXECUTION ROADMAP

| Phase | Scope | Items |
|-------|-------|-------|
| **P0 — Ship blockers** | Section 1 | R1 applicationId, R2 release signing, R3/R4 docs+manifest alignment |
| **P1 — Data integrity** | Sections 3 | C1 (Excel shift), C2 (import re-sync), C3 (email masked), C7 (dates), C4 (employee cascade), C6 (static IP), C8 (Wi-Fi QR), C9 (chassis shrink); add roundtrip regression tests |
| **P2 — Backup completeness** | Section 2 | B1 logo, B2 theme prefs, B3 version guard, B4 all-or-nothing, B5 checksum+manifest, B6 onboarding confirm, B8 metadata; B7 copy fix |
| **P3 — Theme & UI unification** | Sections 5–6 | T1 (light contrast), T2 (surface tokens → U2), U1 SelectionBottomBar, T4 accents, U3 dropdowns, M/unit chips, T7 component themes, U9 maintenance screen |
| **P4 — Hygiene** | Sections 4, 7, 8, 9 | D-1..D-5 dead code removal + prune parity tests, F1–F5, comment sprint, doc sync (all 5 core files) |
| **P5 — Performance polish** | Section 3/S7 | Scanner isolate batching, startup quick-action queue |

Each phase ends with: `flutter analyze` (0 issues) + `flutter test` + manual smoke of the touched flows.

---

## 11. FEATURE IMPLEMENTATION PLAN — enterprise features & network tools

Implements the numbered must-have list: **3, 4, 5, 8** (enterprise features) and **15, 16, 17, 18, 19, 20, 32, 33, 34, 35, 37, 39** (IT/network tools). Numbering follows the consolidated feature lists delivered with this audit.

### 11.0 Shared groundwork — do first (all features depend on it)

| Step | Detail |
|------|--------|
| **G1. Schema v15 migration** | One single version bump 14→15 in `app_database.dart` carrying ALL new tables/columns of Section 11 (see `F1-G1` block below). Follow the documented rule: new `if (oldS < 15)` block, never edit old ones; reuse `addColIfMissing` healing pattern for the new `notes` columns. Never label "planned features, UI pending": ship table + UI together except where noted. |
| **G2. Backup list sync** | Add every new table to `_allBackupTables` (`database_helper.dart:1781–1805`) **in the same release** — otherwise new features produce data silently excluded from backups (violates the 23/23 lockstep invariant verified in Section 2). |
| **G3. MoreScreen integration registry** | Add new tool entries to `more_screen.dart` in the "Network & Sysadmin Suite" / "Tools & Data" tiles (consistent `IconBox + label` tile pattern, `AppColors` accents per T4). Extend quick-actions later only after tools stabilize. |
| **G4. Offline-first permission discipline** | Internet-dependent tools (19 DNS, 20 Whois, plus 16–18 when probing remote networks) must be **explicitly user-triggered** on a per-operation basis — never automatic — to preserve the documented offline-first promise (README R3 fix must then describe the tools). Local-subnet tools (16, 17 on LAN, 18, 32, 33, 35, 37, 39) need no permission changes (`INTERNET` + local sockets already declared). |

**Schema v15 contents (G1):**

```
-- new table: vendor_contacts (feature 34)
CREATE TABLE vendor_contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_type TEXT NOT NULL,        -- 'ISP' | 'Vendor' | 'Domain/Registrar' | 'Internal'
  name TEXT NOT NULL,
  company TEXT DEFAULT '',
  role TEXT DEFAULT '',
  phone_number TEXT DEFAULT '',
  email TEXT DEFAULT '',
  portal_url TEXT DEFAULT '',
  account_number TEXT DEFAULT '',    -- ISP/Vendor account ref
  notes TEXT DEFAULT '',
  created_at TEXT
);

-- new columns: quick technician notes on every asset (feature 39)
ALTER TABLE laptops        ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE network_devices ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE mifis           ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE printers        ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE electronics     ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE access_points   ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE other_devices   ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE subscriptions   ADD COLUMN notes TEXT DEFAULT '';
-- Plus service-maintenance calendar support (feature 35):
ALTER TABLE device_maintenance_logs ADD COLUMN is_planned INTEGER DEFAULT 0;  -- 0 = completed repair, 1 = planned window
ALTER TABLE device_maintenance_logs ADD COLUMN planned_date TEXT DEFAULT ''; -- yyyy-MM-dd, used when is_planned=1
```

---

### 11.1 Feature 3 — Automatic scheduled backups with retention

| Aspect | Plan |
|--------|------|
| Value | Removes the biggest data-loss risk (manual-only backups; one uninstalled phone = workspace gone). |
| Storage | Snapshot JSON (current `exportJson()`) to the app documents dir + optional user-chosen SAF directory via `file_picker` (already a dependency). Naming: `itbox_auto_YYYY-MM-DD_HHmm.json`. |
| Trigger strategy | **Wave 1 (no new deps):** reminder-driven — `ThemeService`-style prefs `autoBackupEnabled`, `autoBackupFrequency` ('Daily'/'Weekly'), `autoBackupReminderTime`. `NotificationService` schedules a recurring "Create today's backup?" notification; tapping it deep-links to `DataHubScreen` where one tap writes the file. Zero background execution, stays within documented architecture. **Wave 2 (optional):** add `workmanager` background isolate to write snapshots silently (bounded: one per period, ~a few hundred KB JSON). Gate Wave 2 behind a setting + doc it in AI_Instructions. |
| Retention policy | Keep last N (default 7) auto snapshots; newest kept, oldest deleted under a `maxAutoBackups` pref (1–30). Stored inside the app-private dir — uninstalled with the phone, so also list a "Copy latest to storage/Drive" one-tap action. |
| UI | `DataHubScreen` new "Automatic Backups" `FintechGroupedCard`: enable toggle, frequency dropdown (`FintechDropdown`), time picker, retention stepper, list of existing snapshots with per-snapshot restore/restore-selected (feeds Feature 4) / share / delete. |
| Edge cases | Restore-validations from B3/B4/B5 apply to auto snapshots too. Never auto-restore. Skip auto-reminder while onboarding incomplete. Reschedule reminders after timezone change / reboot (existing `RECEIVE_BOOT_COMPLETED` receiver already handles boot). |
| Tests | Reminder scheduling unit test, retention-prune unit test on fake timestamps, snapshot round-trip import test. |
| Effort | Wave 1: ~2 days. Wave 2: ~2 days extra. |

### 11.2 Feature 4 — Incremental / selective restore ("restore only these tables")

| Aspect | Plan |
|--------|------|
| Value | Lets admins pull just expenses/logs from 3 days ago without wiping today's inventory — today restore is all-or-nothing. |
| Prereq | Depends on B5 (backup manifest B8) to know table row counts + company identity before restore — implement together. |
| Service | New `DatabaseHelper.importJsonSelective(String json, Set<String> tables)`: validates manifest in B3>= new version guard; inside ONE transaction: `deleteTable(t)` + reinsert **only selected tables**; skip-not-clear for unselected. |
| Dependency grouping | Predefined restore-groups to prevent orphaned references (Section 2 D4): `borrow_logs` auto-selects `employees`, `mifis`, `electronics`; `device_maintenance_logs` auto-selects over referenced device tables; `consumable_logs` → `consumables`. Implement a `restoreGroups` const map; UI shows "employees will also be restored from this backup" hint line. |
| UI | In `DataHubScreen` restore flow: after picking file, show new `showFintechBottomSheet` with a manifest summary (each table: name, row count in backup, checkbox). Buttons: "Restore N selected", "Restore everything". Confirmation via `showConfirmDialog` listing exactly which tables will be replaced (B4-aligned copy). |
| Edge cases | Selective replace of `mifis`/`electronics` while active `borrow_logs` exist on-device: post-import `syncDeviceStatuses()` + `reconcileReminders()` (same invariant as C2). Selective restore of tables `borrow_logs` depends on = show warning; never silently break links (paired with C4 cascade once fixed). |
| Tests | Parity test: full restore vs selective restore of identical table yields identical rows; partial-economy test that unselected tables untouched. |
| Effort | ~2 days (after B-Phase groundwork). |

### 11.3 Feature 5 — Multi-workspace support

| Aspect | Plan |
|--------|------|
| Value | consultants supporting several SMB clients from one phone; each client gets isolated data + backup identity. |
| Architecture | Workspace registry stored in `SharedPreferences` as JSON list: `{id, name, logoPath, createdAt, lastOpened}` (company name + logo move INTO the workspace record — current `CompanyService` keys become per-workspace). Database per workspace: `itbox_<id>.db` (Drift accepts a filename; current code path opens `itbox.db` — parameterize). |
| Switching flow | `switchWorkspace(id)`: dispose/close `AppDatabase.instance` + flush `TableNotifier` debounce, restore+reload `CompanyService` fields for that workspace, reopen DB, fire `TableNotifier` full-invalidation, re-render root. Implement as a small `WorkspaceService` (ChangeNotifier, same pattern as `ThemeService`); `ITBoxApp` listens. |
| Singletons to convert | `AppDatabase.instance`, `DatabaseHelper.init()` idempotence, `CompanyService` (name/onboarded/logo per workspace), `DatabaseHelper.syncDeviceStatuses()` on open (data-normalization per profile). `ThemeService` stays global (appearance is device-level, not workspace-level) — this is why B2 keeps theme prefs separate from workspace backup. |
| Backup identity | `exportJson` gains `workspace_id` + `workspace_name` metadata (B8); import on a different workspace = "restore into this workspace" or "create new workspace from backup" — the latter is also the onboarding path upgrade. |
| UI | Workspace switcher entry in `SettingsScreen` top (avatar/name chip → `showFintechBottomSheet` list + "New workspace" → mini-onboarding). Badge on `HomeScreen` header. No per-screen changes needed (singletons reloaded). |
| Risks | Greatest-scope item on the list; touches open/close lifecycle, notifications (reminders must target the active workspace's borrow set — reconcile on switch), QuickActions handlers (route to workspace if set). Serialize AFTER P0/P1 in roadmap. |
| Tests | Switch cycle test (create workspace A, add data, switch to B empty, switch back — data intact), backup-restore-cross-workspace round-trip. |
| Effort | ~4–5 days, riskiest feature — schedule behind a feature flag until stable. |

### 11.4 Feature 8 — Audit-trail export (PDF / JSON)

| Aspect | Plan |
|--------|------|
| Value | Turns the existing `audit_activities` trail (schema v14, currently in-app only) into a compliance artifact. |
| Service | Extend `PdfReportService` (or new `AuditPdfService`) → `generateAndShareAuditReport({filters})`: A4 portrait table (timestamp, type, title, description wrapped, row-zebra using AppColors lightCard/darkCard per ExcelService conventions). JSON option = raw filtered rows via `share_plus` (matches existing backup pipeline conventions). |
| UI | `ActivityFeedScreen` toolbar: `FintechActionButton` ×2 (PDF / JSON) + date-range filter bottom sheet (Reuse the date-range dialog pattern already used for expense export). Show generated file via `SharePlus`. |
| Cutover | Wire into `clearAuditActivities` existing purge action: after purge, offer "Export before clearing" one-tap (protects evidence hygiene). |
| Tests | PDF output smoke (rows >100 paginate), empty-trail empty-state (reuse `EmptyState`). |
| Effort | ~1–1.5 days. |

### 11.5 Feature 15 — Full-text global search (home screen)

| Aspect | Plan |
|--------|------|
| Value | One search bar to find an asset/SSID/serial/contact across every entity — highest daily-driver impact. |
| Service | New `GlobalSearchService` (async, on main isolate) with per-table field mapping: laptops (number/model/cpu/user), network_devices (number/model/gateway/wifi_name), mifis (number/model/tag/phone), electronics (name/details), printers (number/model/location), access_points, employees (name/phone), emails, log_entries (problem/employee), expenses (item/details), bills, subscriptions, wifi_networks (SSID/location), account_passwords (platform/username), other_devices, vendor_contacts (11.7), notes columns (11.16-result). One `Future.wait([...])` fan-out using Drift `select().where(e.field.contains(q))` typed builders (no raw SQL, per AI_Instructions rule). Debounce 250ms. |
| UI | Search icon on `DashboardScreen` header (pattern consistent with logged "search to find" gaps) → full-screen `SearchScreen` (own Scaffold rule) with `SearchBar2 (noPadding:false)`, grouped result sections by entity with entity accent icon + subtitle (entity type + identifying field count), tap → entity detail route (navigate per existing detail-share flows; for entities without a detail screen, open the concrete list screen filtered). |
| Performance | Cap per-table results (e.g. 20) + "show more in <entity>" footer → navigates to the entity screen; use lowercase contains — table sizes are small (SMB dataset). Index: skip FTS for wave 1; revisit if datasets grow past 10k rows. |
| Tests | Cross-entity hit test + routing test; empty query shows recent-entities hint (optional). |
| Effort | ~2–2.5 days. |

### 11.6 Tools 16–20 — Network diagnostics suite (new folder `lib/screens/network_tools/diagnostics/`)

| Tool | Implementation plan |
|------|------|
| **16 Ping / Multi-ping monitor** | New `pingMonitor` stream in `NetworkScannerService` (singles-host variant of existing ICMP sweep + concurrency tuning loop). Persistent "monitored hosts" stored in a new prefs JSON (`ping_monitor_v1` similar to `custom_switch_patch_chassis_v1` — no new table needed) — or reuse `static_ips` flags. Per-host card shows live status dot, min/avg/max latency + loss % (fl_chart spike chart), pause/resume per host. Add "Monitor from scan results" button on scanner cards (1-tap pin). |
| **17 Traceroute** | New `traceRoute(host)` in `NetworkScannerService`: TTL-incremented UDP probes (existing UDP socket infra), parse ICMP Time-Exceeded responses via raw socket callbacks — Dart has no raw ICMP, so use the *dual platform strategies* documented in the scanner (Windows: `SendARP` per hop + TCP connect trick; fallback: hop timing via UDP connect + errno). Output list: TTL, hop IP, resolved MAC + OUI vendor (existing lookup), DNS PTR (existing resolver), per-hop latency chart. Cap TTL 15. |
| **18 TCP port reachability tester** | Extend `scanHostPorts()` for arbitrary (host, ports[]) probes with service presets (SSH 22, SMB 445, HTTP 80/443, RDP 3389, SNMP 161/UDP, MSSQL 1433, SMTP 25, DNS 53, VNC 5900). Reuse the existing banner-grabbing code path ("server banner" lines) for identity when open. Output card list with open/closed/filtered + median latency. |
| **19 DNS lookup suite (internet, user-triggered)** | Minimal DNS client over UDP :53 implemented with the existing socket infra (build + parse A/AAAA/NS/MX/TXT/PTR/CNAME — RFC-1035 wire format; ~200 lines) — no new dependency, preserving "no new heavy frameworks" spirit, and works with custom resolvers (8.8.8.8 / ISP DNS). UI: query form (FintechGroupedCard) + result rows in `credentialFont()`, timing, resolver selector. Contract honored: only runs when user taps "Resolve". |
| **20 Whois / MAC lookup (internet, user-triggered)** | MAC vendor: already covered by OUI db (offline). Whois over TCP :43 raw socket (same infra), query domain → flat WHOIS text → parse registrar/expiry/nameservers for the extendable fields → display in a DetailRow section. Plan the offline fallback message early. UX copy: "requires internet". |
| Stance | All five ship as separate screens under **More → Sysadmin suite** (individual tiles consistent with the existing scanner/CIDR/tools), sharing a new `diagnostics_common.dart` (host input field, result card, copy/share row). Follow the FintechActionButton toolbar + `SearchBar2` pattern like the scanner screen. |

### 11.7 Feature 34 — IT runbook & contacts directory

| Aspect | Plan |
|--------|------|
| Value | Central who-to-call: ISP hotlines, vendor support, registrar creds — the runbook page every IT lead needs on phone during an outage. |
| Data | New `vendor_contacts` table (schema in 11.0-G1). |
| UI | `VendorContactsScreen` + `VendorContactFormScreen` (follow standard form-screen conventions + `AppTextField`), grouped by `contact_type` sections, per-card 1-tap tel/`tel:` · mail copy · portal launch via `url_launcher` (already integrated), searchable via `SearchBar2`. Add a "call hotline" directly on the screen top-most card (quick emergency access — complements item 40 which stays out-of-scope of this plan). Seeded categories: Internet/ISP, Hardware Vendor, Domain/Registrar, Cloud/SaaS vendor, Internal escalation. |
| Backup | Add `vendor_contacts` to `_allBackupTables` (G2, mandatory same-release). |
| Effort | ~1.5 days. |

### 11.8 Feature 32 — Topology documentation export (one-page network map PDF)

| Aspect | Plan |
|--------|------|
| Value | The "handover binder" page — a single A4/A3 sheet showing internet → router → switches/APs → devices. |
| Service | New `TopologyPdfService` (sibling of executive_health_pdf_service). Build a graph purely from existing tables (no manual input): internet (cloud shape) → `network_devices` (routers/gateways) → `access_points` (via `port_number` mapping when present) and `mifis` → `switch_patch_ports` ports (via `device_id`) → endpoints (`static_ips` + laptops assigned + printers). Use `pdf` canvas primitives (rounded boxes + lines + labels at 90°/orthogonal connectors) — no graph-layout library (keeps deps unchanged). Map per-connection falls back to plausible listing (session as listed sections, not forced geometric layout) to avoid engine complexity. |
| UI | DataHub "Network Map" card/button next to the Executive infographic — generate + share/print. Optionally show per-row legend (counts per node type). |
| Tests | PDF smoke test with sample dataset; empty-inventory empty-state message. |
| Effort | ~2 days. |

### 11.9 Feature 33 — Router/ISP config backup parser

| Aspect | Plan |
|--------|------|
| Value | Auto-populate Wi-Fi vault + router records from a config file the tech already has. |
| Scope decision | Only TEXT-format firmware dumps are parseable safely: TP-Link `.tra` / D-Link / Hikvision style `key=value` lines, plus generic grep of common keys (`wl_ssid`, `wlan_ssid`, `wlan_wpa_psk`, `pppoe_*`, `lan_ipaddr`). Plan an **"Unsupported/binary config" friendly message** with the vendor-not-supported list (no false promises from binary .enc/.bin backups). |
| Flow | FilePicker `.txt/.cfg/.conf/.tra/.ini` → `compute()` isolate (same pattern as Excel decode) → `ConfigParserService` returns `ParsedRouterConfig{ssid, wifiPassword, wanType, wanUser, adminUser, adminUrl, gateway, ...}` → preview sheet (fields found with checkmarks, per-field mapping incl. manual edit) → 1-tap "Save as Router entry" or "Save as Wi-Fi record" or both → generates Audit Activity rows. |
| Tests | Parser unit tests against fixture configs per vendor; malformed/empty file error path. |
| Effort | ~2.5 days. |

### 11.10 Feature 35 — Change/maintenance calendar

| Aspect | Plan |
|--------|------|
| Value | Planned windows become bookmarkable: "December maintenance Sundays" with a printable notice. |
| Data | `device_maintenance_logs` extension (is_planned / planned_date) in schema v15 (11.0-G1). |
| UI | New `MaintenanceCalendarScreen` under Maintenance context: month-grid `GridView` (7-col), colored dots per day (planned/emerald; completed/blue), day-bottom-sheet listing entries + "Add planned window" (opens DeviceMaintenanceScreen in plan-mode setting is_planned=1 + date), filter by device type chips. |
| PDF | "Generate notice sheet" button: reusable print sheet — header date range, table of planned windows (device, description, duration, technician), custom footer space for bulletin-board print (follows existing `label_service` A4 / execHealth pattern). |
| Reminders (optional, small) | 1-day-before reminder via NotificationService on planned windows — reuses the alarm channel pattern from borrow reminders. |
| Effort | ~2.5 days. |

### 11.11 Feature 37 — Unit & data-size converter (quick utility)

| Aspect | Plan |
|--------|------|
| Value | The "mental math killer" — bandwidth scheduling, storage math, link budget. |
| UI | `UnitConverterScreen` under **More → Tools**: segmented tabs (Data size / Bandwidth / Transfer time / Latency) — `FintechSegmentedControl` IF P3 adopts it (see U5) else the standard chip row. Two-field bidirectional inputs using `AppTextField` + numeric keyboards, instant recalc via `ValueNotifier`/setState, results row in `credentialFont()`. Include: MB/GB/TB (+MiB/GiB toggle), Mbps↔MB/s, transfer-time calculator ("how long to push 250GB at 300Mbps"), and a `/8 /24`-free simple percentage overhead row. Pure UI, zero schema impact — ship anytime. |
| Effort | ~1 day. |

### 11.12 Feature 39 — Quick notes per device

| Aspect | Plan |
|--------|------|
| Value | The technician scratchpad: "borrow VIN cable VGA port 2", "warranty till Jan-27", "user changed password" — free-form context per asset. |
| Data | `notes TEXT DEFAULT ''` on 8 tables in schema v15 (11.0-G1). Because export/backup walks `SELECT *`, notes flow through backups automatically (G2 lockstep) and Excel exports gain a trailing Notes column (coordinate with Excel import column-mapping table + C7/C1 column alignment work in P1 to avoid re-introducing a shift bug). |
| UI | In each entity's detail bottom sheet + form screen: `AppTextField(multiline: true)` inside the final `FintechGroupedCard` "Notes" section. Wrapping/soft-wrap defaults fine. For list screens the detail sheet is the only surface (no list clutter). |
| Tests | Existing parity/roundtrip tests extended: persist→reload preserves notes incl. newlines; backup/restore keeps notes. |
| Effort | ~1.5 days including wiring into detail sheet templates. |

---

### 11.13 Implementation waves & dependency ordering

| Wave | Items | Why this order | Effort |
|------|-------|----------------|--------|
| **W1 (needs P0+P1 done first)** | G1–G4 groundwork + 39 notes + 37 converter + 8 audit export + 34 runbook | Low-risk, high-value UI features; v15 schema lands once with everything below | ~6 days |
| **W2** | 15 global search + 3 auto-backup Wave 1 + 4 selective restore (pairs with B-Phase) | Search sets up schema-driven field maps reusable by rest; backup trio shares code paths | ~5 days |
| **W3** | 16–20 diagnostics suite (ping, traceroute, ports, DNS, WHOIS) + 32 topology | Shared diagnostics_common screen kit; all are additive screens | ~8 days |
| **W4** | 33 config parser + 35 maintenance calendar | Calendar depends on nothing new; parser best after Wi-Fi vault UI stable | ~5 days |
| **W5 (riskiest last)** | 5 multi-workspace | Touches singletons/DB lifecycle + notifications; only after data-integrity phases P1/P2 are green | ~5 days |
| **W6 (optional)** | 3 auto-backup Wave 2 (workmanager silent snapshot) | Only if background execution is validated on target devices | ~2 days |

**Total: ~31 days of implementation effort** (excluding P0–P5 remediation phases).

Per-wave exit criteria (same standard as phases P0–P5):
1. `flutter analyze` → 0 issues; `flutter test` green including new round-trip/parity tests.
2. New tables present in `_allBackupTables` + verified in an export/import round-trip test.
3. CLAUDE.md / AI_Instructions / STRUCTURE.md / CHANGELOG.md / README.md updated (mandatory doc-sync rule) — including the new ERD entries and backup-format sample JSON.
4. Offline-first promise re-verified: internet-dependent tools (19, 20 + 16–18 against public IPs) are user-triggered only.
